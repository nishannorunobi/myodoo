"""
Odoo Agent HTTP Server — runs inside myodoo-app container on port 8896.

A thin sysadmin agent for the Odoo 17 service running in the same container.
Odoo itself is managed as a tool under tools/odoo/ (start/stop/health), so the
agent can supervise the service; the agent also serves a small dashboard, a
liveness/health endpoint, and an AI chat about the running Odoo instance.

Endpoints:
  GET  /                       standalone web UI
  GET  /health                 liveness + Odoo service status
  GET  /api/tools              list managed tools (discovered from tools/*)
  POST /api/tools/{name}/{action}  run a tool lifecycle action (build/start/stop/health/clean)
  POST /api/chat/clear         clear AI chat history
  POST /api/tasks              one-shot AI task
  WS   /ws/chat                streaming AI chat
"""
import asyncio
import json
import os
import signal
import socket
import sys
from datetime import datetime
from pathlib import Path

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
import anthropic as _anthropic
from loguru import logger
from pydantic import BaseModel

# ── Loguru setup ──────────────────────────────────────────────────────────────
import logging as _logging

class _Interceptor(_logging.Handler):
    def emit(self, record):
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno
        frame, depth = _logging.currentframe(), 2
        while frame and frame.f_code.co_filename == _logging.__file__:
            frame = frame.f_back
            depth += 1
        logger.opt(depth=depth, exception=record.exc_info).log(level, record.getMessage())

_logging.basicConfig(handlers=[_Interceptor()], level=0, force=True)
logger.remove()
logger.add(
    sys.stderr,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level:<8}</level> | <cyan>{name}</cyan>:<cyan>{line}</cyan> — <level>{message}</level>",
    level="INFO",
    colorize=True,
)

# ── Mirror log file ───────────────────────────────────────────────────────────
AGENT_DIR   = Path(__file__).parent
_script_rel = "odoo-agent/server_py.log"
_log_mirror_root = os.environ.get("LOG_MIRROR_ROOT", "")
if _log_mirror_root:
    _mirror_log = Path(_log_mirror_root) / _script_rel
else:
    _mirror_log = AGENT_DIR / "memory" / "server.log"
_mirror_log.parent.mkdir(parents=True, exist_ok=True)
logger.add(
    str(_mirror_log),
    format="{time:YYYY-MM-DD HH:mm:ss} | {level:<8} | {name}:{line} — {message}",
    level="INFO",
    rotation="50 MB",
    retention=10,
    colorize=False,
)
MEMORY_DIR  = AGENT_DIR / "memory"
MEMORY_DIR.mkdir(exist_ok=True)

load_dotenv(AGENT_DIR / "agent.conf")

ODOO_PORT         = int(os.environ.get("ODOO_PORT", "8069"))
ODOO_LP_PORT      = int(os.environ.get("ODOO_LONGPOLLING_PORT", "8072"))
ODOO_URL          = f"http://localhost:{ODOO_PORT}"

app = FastAPI(title="Odoo Agent")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# Dev tool: never let the browser cache JS/HTML/CSS, otherwise an edit→Start deploy
# keeps showing stale assets. Serve static + the index with no-store.
@app.middleware("http")
async def _no_cache_assets(request, call_next):
    resp = await call_next(request)
    p = request.url.path
    if p == "/" or p.startswith("/static/"):
        resp.headers["Cache-Control"] = "no-store, max-age=0"
    return resp


app.mount("/static", StaticFiles(directory=str(AGENT_DIR / "static")), name="static")

# ── Process / port helpers ──────────────────────────────────────────────────────

def _port_listening(port: int | str, host: str = "127.0.0.1") -> bool:
    """True if something is accepting TCP connections on `port`.

    Status is read from the port, not a PID file: Odoo is launched by the
    container startup (via tools/odoo/start.sh) which may bypass the agent, so
    the port is the source of truth.
    """
    try:
        port = int(port)
    except (TypeError, ValueError):
        return False
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        return s.connect_ex((host, port)) == 0


async def _stream_script(cmd: list[str], env: dict | None = None):
    """SSE-stream a subprocess; yields `data: <line>\n\n`."""
    run_env = {**os.environ, **(env or {})}

    async def generate():
        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=run_env,
            )
        except FileNotFoundError:
            yield f"data: [ERROR] '{cmd[0]}' not found on PATH inside the container.\n\n"
            yield "data: __done__\n\n"
            return
        except Exception as e:
            yield f"data: [ERROR] failed to launch {cmd[0]}: {e}\n\n"
            yield "data: __done__\n\n"
            return

        # Stream lines, but stop once the script process itself exits. A start
        # script launches a detached daemon (odoo-bin) that may keep the stdout
        # pipe's write-end open, so readline() would never see EOF and the SSE
        # stream would hang. Polling proc.returncode avoids that.
        while True:
            try:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=0.5)
            except asyncio.TimeoutError:
                if proc.returncode is not None:
                    break
                continue
            if not line:
                break
            yield f"data: {line.decode(errors='replace').rstrip()}\n\n"

        try:
            while True:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=0.2)
                if not line:
                    break
                yield f"data: {line.decode(errors='replace').rstrip()}\n\n"
        except asyncio.TimeoutError:
            pass

        rc = proc.returncode if proc.returncode is not None else await proc.wait()
        yield f"data: [exit {rc}]\n\n"
        yield "data: __done__\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/")
async def index():
    return FileResponse(str(AGENT_DIR / "static" / "index.html"))

@app.get("/health")
async def health():
    odoo_ok = _port_listening(ODOO_PORT)
    lp_ok   = _port_listening(ODOO_LP_PORT)

    odoo_reachable = False
    if odoo_ok:
        try:
            async with httpx.AsyncClient(timeout=2) as client:
                r = await client.get(f"{ODOO_URL}/web/health")
                odoo_reachable = r.status_code == 200
        except Exception:
            pass

    return {
        "odoo_running":        odoo_ok,
        "odoo_reachable":      odoo_reachable,
        "longpolling_running": lp_ok,
        "agent_running":       True,
        "timestamp":           datetime.now().isoformat(timespec="seconds"),
    }

# ── Tool framework ──────────────────────────────────────────────────────────────
# The agent is a thin sysadmin invoker. Each managed tool is a folder under tools/
# with a tool.conf plus the lifecycle scripts (build/start/stop/health/clean .sh).
# Adding a new tool = drop a new folder; no Python change needed.
TOOLS_DIR     = AGENT_DIR / "tools"
_TOOL_ACTIONS = ("build", "start", "stop", "health", "clean", "upgrade")


def _parse_tool_conf(conf: Path) -> dict:
    data = {}
    for line in conf.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        data[k.strip().lower()] = v.strip()
    return data


def _discover_tools() -> list[dict]:
    tools = []
    if not TOOLS_DIR.exists():
        return tools
    for d in sorted(TOOLS_DIR.iterdir()):
        conf = d / "tool.conf"
        if not d.is_dir() or not conf.exists():
            continue
        meta = _parse_tool_conf(conf)
        name = meta.get("name", d.name)
        port = meta.get("port", "")
        tools.append({
            "name":    name,
            "label":   meta.get("label", name),
            "port":    port,
            "order":   int(meta.get("order") or 99),
            "actions": [a for a in _TOOL_ACTIONS if (d / f"{a}.sh").exists()],
            "running": _port_listening(port),
        })
    tools.sort(key=lambda t: t["order"])
    return tools


@app.get("/api/tools")
async def list_tools():
    return {"tools": _discover_tools()}


@app.post("/api/tools/{name}/{action}")
async def run_tool_action(name: str, action: str):
    if action not in _TOOL_ACTIONS:
        return JSONResponse({"error": f"unknown action '{action}'"}, status_code=400)
    tool_dir = (TOOLS_DIR / name).resolve()
    # guard against path traversal — must be a direct child of tools/
    if tool_dir.parent != TOOLS_DIR.resolve() or not tool_dir.is_dir():
        return JSONResponse({"error": f"unknown tool '{name}'"}, status_code=404)
    script = tool_dir / f"{action}.sh"
    if not script.exists():
        async def missing():
            yield f"data: [ERROR] tool '{name}' has no {action}.sh\n\n"
            yield "data: __done__\n\n"
        return StreamingResponse(missing(), media_type="text/event-stream")
    # The scripts manage their own PID files, so don't pass pid_file here.
    return await _stream_script(["bash", str(script)])

# ── AI Chat ───────────────────────────────────────────────────────────────────

_chat_history: list[dict] = []
_SYSTEM_PROMPT = """You are an Odoo administration assistant embedded in a Dockerized workspace.
You help operate and troubleshoot an Odoo 17 (built from source) instance running in the
myodoo-app container. It reuses the mypostgresql_db Postgres over my_docker_network.
- Odoo web UI: port 8069
- Odoo longpolling/bus: port 8072
- This odoo-agent dashboard: port 8896

You can describe how to start/stop the Odoo service (managed as a tool by this agent),
explain Odoo modules and configuration, read tracebacks, and suggest fixes. Be concise
and practical. Wrap shell commands and config snippets in code blocks."""

@app.post("/api/chat/clear")
async def chat_clear():
    _chat_history.clear()
    return {"ok": True}

@app.websocket("/ws/chat")
async def ws_chat(ws: WebSocket):
    await ws.accept()
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        await ws.send_json({"type": "error", "content": "ANTHROPIC_API_KEY not set in agent.conf"})
        return

    # Send history
    for msg in _chat_history:
        await ws.send_json({"type": "history_msg", "role": msg["role"],
                            "content": msg["content"][0]["text"] if isinstance(msg["content"], list) else msg["content"],
                            "ts": ""})
    try:
        while True:
            data = await ws.receive_json()
            user_text = data.get("content", "").strip()
            if not user_text:
                continue
            _chat_history.append({"role": "user", "content": user_text})
            client = _anthropic.Anthropic(api_key=api_key)
            try:
                with client.messages.stream(
                    model="claude-haiku-4-5-20251001",
                    max_tokens=2048,
                    system=_SYSTEM_PROMPT,
                    messages=_chat_history,
                ) as stream:
                    full = ""
                    for text in stream.text_stream:
                        full += text
                        await ws.send_json({"type": "text", "content": text})
                _chat_history.append({"role": "assistant", "content": full})
            except Exception as e:
                await ws.send_json({"type": "error", "content": str(e)})
            await ws.send_json({"type": "done"})
    except WebSocketDisconnect:
        pass

# ── Agent tasks (docker-manager-agent integration) ────────────────────────────

class TaskRequest(BaseModel):
    task: str

@app.post("/api/tasks")
async def run_task(req: TaskRequest):
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return {"result": "ANTHROPIC_API_KEY not configured"}
    client = _anthropic.Anthropic(api_key=api_key)
    h = await health()
    ctx = f"Odoo health: {json.dumps(h)}"
    resp = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        system=_SYSTEM_PROMPT + f"\n\nCurrent context: {ctx}",
        messages=[{"role": "user", "content": req.task}],
    )
    return {"result": resp.content[0].text}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8896, reload=False)
