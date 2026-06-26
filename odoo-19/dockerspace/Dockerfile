# Odoo 19 from source. Lean Python base + Odoo's Python/system deps.
# Odoo 19 targets a newer Python than the 17 stack, so this uses 3.12.
# The source is MOUNTED at runtime (see docker-compose.yml), so editing source
# needs no rebuild — only a requirements.txt change requires rebuilding.
FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1

# System libs Odoo's Python wheels build against + wkhtmltopdf for PDF reports.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential python3-dev curl \
        libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev \
        libjpeg-dev zlib1g-dev libffi-dev \
        postgresql-client wkhtmltopdf fonts-dejavu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /myodoo/odoo

# Install Odoo's Python deps first so this layer is cached unless requirements change.
COPY odoo/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

EXPOSE 8069 8072

# Source + odoo.conf are mounted at runtime; ODOO_RC (set in compose) points
# odoo-bin at the mounted config.
CMD ["./odoo-bin"]
