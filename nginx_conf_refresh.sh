#!/bin/bash
set -e

echo "============================================"
echo " 🔄 Refrescando configuración Nginx (Odoo SSL)"
echo "============================================"

# ========================
# VARIABLES
# ========================
DOMAIN_PROD="intranet.zolectrum.com"
ODOO_PORT_PROD="8069"
LONGPOLLING_PROD="8072"

DOMAIN_TEST="test.zolectrum.com"
ODOO_PORT_TEST="8010"
LONGPOLLING_TEST="8073"

echo "👉 Producción: $DOMAIN_PROD ($ODOO_PORT_PROD / $LONGPOLLING_PROD)"
echo "👉 Test: $DOMAIN_TEST ($ODOO_PORT_TEST / $LONGPOLLING_TEST)"
echo "============================================"

# ========================
# CONFIG NGINX con SSL
# ========================

# Producción
cat > /etc/nginx/sites-available/$DOMAIN_PROD.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_PROD;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_PROD;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_PROD/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_PROD/privkey.pem;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    client_max_body_size 200m;

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

    location /websocket {
        proxy_pass http://127.0.0.1:$LONGPOLLING_PROD;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Test
cat > /etc/nginx/sites-available/$DOMAIN_TEST.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_TEST;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_TEST;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_TEST/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_TEST/privkey.pem;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    client_max_body_size 200m;

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

    location /websocket {
        proxy_pass http://127.0.0.1:$LONGPOLLING_TEST;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/$DOMAIN_PROD.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/$DOMAIN_TEST.conf /etc/nginx/sites-enabled/

# ========================
# REINICIO NGINX
# ========================
echo "---- Probando configuración ----"
sudo nginx -t
echo "---- Reiniciando Nginx ----"
sudo systemctl reload nginx

echo "✅ Configuración sobrescrita con SSL correctamente"
