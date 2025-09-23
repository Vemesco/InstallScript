#!/bin/bash
set -e

echo "============================================"
echo " 🚀 Instalador Nginx + Odoo (Producción / Test)"
echo "============================================"

# ========================
# VARIABLES FIJAS
# ========================
DOMAIN_PROD=".com"
ODOO_PORT_PROD="8069"
LONGPOLLING_PROD="8072"

DOMAIN_TEST=".com"
ODOO_PORT_TEST="8010"
LONGPOLLING_TEST="8073"

ADMIN_EMAIL="admin@vemesco.com"

echo "👉 Producción: $DOMAIN_PROD ($ODOO_PORT_PROD / $LONGPOLLING_PROD)"
echo "👉 Test: $DOMAIN_TEST ($ODOO_PORT_TEST / $LONGPOLLING_TEST)"
echo "👉 Certbot Email: $ADMIN_EMAIL"
echo "============================================"

# ========================
# DEPENDENCIAS
# ========================
echo "---- Instalando dependencias ----"
sudo apt update
sudo apt install -y nginx ufw snapd

# ========================
# CERTBOT SNAPD
# ========================
echo "---- Instalando Certbot (via snapd) ----"
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# ========================
# FIREWALL
# ========================
echo "---- Configurando Firewall ----"
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw allow 8069
sudo ufw allow 8010
sudo ufw allow 8072
sudo ufw allow 8073
sudo ufw reload

# ========================
# CONFIG NGINX (HTTP primero)
# ========================
echo "---- Creando configuración HTTP temporal (sin SSL) ----"

# Producción
cat > /etc/nginx/sites-available/$DOMAIN_PROD.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_PROD;

    location / {
        proxy_pass http://127.0.0.1:$ODOO_PORT_PROD;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:$LONGPOLLING_PROD;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

# Test
cat > /etc/nginx/sites-available/$DOMAIN_TEST.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_TEST;

    location / {
        proxy_pass http://127.0.0.1:$ODOO_PORT_TEST;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:$LONGPOLLING_TEST;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/$DOMAIN_PROD.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/$DOMAIN_TEST.conf /etc/nginx/sites-enabled/

echo "---- Probando y reiniciando Nginx (HTTP) ----"
sudo nginx -t && sudo systemctl restart nginx

# ========================
# CERTIFICADOS SSL
# ========================
echo "---- Generando certificados SSL con Certbot ----"
sudo certbot --nginx -d $DOMAIN_PROD --email $ADMIN_EMAIL --agree-tos --non-interactive
sudo certbot --nginx -d $DOMAIN_TEST --email $ADMIN_EMAIL --agree-tos --non-interactive

# ========================
# SOBRESCRIBIR CONFIG FINAL CON SSL
# ========================
echo "---- Refrescando configuración Nginx con SSL ----"
sudo /etc/InstallScript/nginx_conf_refresh.sh

# ========================
# NOTA ODOO
# ========================
echo "✅ Instalación finalizada"
echo "============================================"
echo "NOTA IMPORTANTE en Odoo:"
echo "  proxy_mode = True"
echo "  longpolling_port = False"
echo "  gevent_port = (usar el puerto del upstream longpolling: 8072 o 8073)"
echo "  workers = (ajustar según núcleos CPU)"
echo "============================================"
