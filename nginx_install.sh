#!/bin/bash

# This script installs Nginx and configures proxy servers for Odoo.
# It allows configuring up to two instances (production and test) with their own domains and ports.

# Input requirements:
# DOMAIN_PROD: Domain for the production environment (e.g., "prod.yourcompany.com")
# PORT_PROD: Odoo server port in production (e.g., "8069")
# LONGPOLLING_PORT_PROD: Longpolling port in production (e.g., "8072")
# DOMAIN_TEST: Domain for the test environment (e.g., "test.yourcompany.com")
# PORT_TEST: Odoo server port in test (e.g., "8070")
# LONGPOLLING_PORT_TEST: Longpolling port in test (e.g., "8073")
# ADMIN_EMAIL: Email for Certbot configuration (e.g., "admin@yourcompany.com")

# Usage:
# ./nginx_installer.sh prod.yourcompany.com 8069 8072 test.yourcompany.com 8070 8073 admin@yourcompany.com

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Validate that all input parameters have been provided
if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <DOMAIN_PROD> <PORT_PROD> <LONGPOLLING_PORT_PROD> <DOMAIN_TEST> <PORT_TEST> <LONGPOLLING_PORT_TEST> <ADMIN_EMAIL>"
    exit 1
fi

DOMAIN_PROD="$1"
PORT_PROD="$2"
LONGPOLLING_PORT_PROD="$3"
DOMAIN_TEST="$4"
PORT_TEST="$5"
LONGPOLLING_PORT_TEST="$6"
ADMIN_EMAIL="$7"

echo "---- Installing and configuring Nginx ----"

# Update and install Nginx
sudo apt-get update
sudo apt-get install -y nginx

# Create the configuration for the production environment
echo "---- Creating Nginx configuration file for production: $DOMAIN_PROD ----"
cat <<EOF | sudo tee /etc/nginx/sites-available/$DOMAIN_PROD > /dev/null
upstream odoo_prod_longpolling {
    server 127.0.0.1:$LONGPOLLING_PORT_PROD;
}
upstream odoo_prod {
    server 127.0.0.1:$PORT_PROD;
}
server {
    listen 80;
    server_name $DOMAIN_PROD;

    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

    access_log /var/log/nginx/$DOMAIN_PROD-access.log;
    error_log /var/log/nginx/$DOMAIN_PROD-error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;
    client_max_body_size 200;

    gzip on;
    gzip_min_length 1100;
    gzip_buffers 4 32k;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
    gzip_vary on;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 64k;

    location / {
        proxy_pass http://odoo_prod;
        proxy_redirect off;
    }

    location /longpolling {
        proxy_pass http://odoo_prod_longpolling;
    }
}
EOF

# Create the configuration for the test environment
echo "---- Creating Nginx configuration file for test: $DOMAIN_TEST ----"
cat <<EOF | sudo tee /etc/nginx/sites-available/$DOMAIN_TEST > /dev/null
upstream odoo_test_longpolling {
    server 127.0.0.1:$LONGPOLLING_PORT_TEST;
}
upstream odoo_test {
    server 127.0.0.1:$PORT_TEST;
}
server {
    listen 80;
    server_name $DOMAIN_TEST;

    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

    access_log /var/log/nginx/$DOMAIN_TEST-access.log;
    error_log /var/log/nginx/$DOMAIN_TEST-error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;
    client_max_body_size 0;

    gzip on;
    gzip_min_length 1100;
    gzip_buffers 4 32k;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
    gzip_vary on;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 64k;

    location / {
        proxy_pass http://odoo_test;
        proxy_redirect off;
    }

    location /longpolling {
        proxy_pass http://odoo_test_longpolling;
    }
}
EOF

# Enable sites and reload Nginx
echo "---- Enabling sites and reloading Nginx ----"
sudo ln -s /etc/nginx/sites-available/$DOMAIN_PROD /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/$DOMAIN_TEST /etc/nginx/sites-enabled/

# Remove the default Nginx configuration
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi

sudo nginx -t && sudo systemctl restart nginx

echo "---- Nginx configuration finished. Certbot will now be installed for SSL. ----"
# Enable SSL with Certbot
sudo apt install snapd -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo apt-get install -y python3-certbot-nginx

# Enable SSL for both domains
echo "---- Enabling SSL/HTTPS for $DOMAIN_PROD ----"
sudo certbot --nginx -d $DOMAIN_PROD --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
echo "---- Enabling SSL/HTTPS for $DOMAIN_TEST ----"
sudo certbot --nginx -d $DOMAIN_TEST --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect

sudo nginx -t && sudo systemctl restart nginx

echo "Nginx installation and configuration script completed successfully!"
echo "Configurations are located at /etc/nginx/sites-available/$DOMAIN_PROD and /etc/nginx/sites-available/$DOMAIN_TEST"
