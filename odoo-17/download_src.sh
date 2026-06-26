VERSION=17.0
rm -rf odoo
wget https://github.com/odoo/odoo/archive/refs/heads/${VERSION}.tar.gz -O odoo-${VERSION}.tar.gz
mkdir -p odoo
tar -xzf odoo-${VERSION}.tar.gz -C odoo --strip-components=1
rm odoo-${VERSION}.tar.gz
