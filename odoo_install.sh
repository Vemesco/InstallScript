#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 16.04, 18.04, 20.04 and 22.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo10"
OE_HOME="/opt/$OE_USER"
OE_CONFIG="${OE_USER}-server"
OE_HOME_EXT="$OE_HOME/$OE_CONFIG"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 16.0, 15.0, 14.0 or saas-22. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 16.0
OE_VERSION="10.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# Installs postgreSQL V14 instead of defaults (e.g V12 for Ubuntu 20/22) - this improves performance
INSTALL_POSTGRESQL_FOURTEEN="False"
# Set this to True if you want to install Nginx!
INSTALL_NGINX="False"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="False"
# Set the website name
WEBSITE_NAME="_"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="False"
# Provide Email to register ssl certificate
ADMIN_EMAIL="admin@vemesco.com"
##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/16.0/administration/install.html

# Check if the operating system is Ubuntu 22.04
if [[ $(lsb_release -r -s) == "22.04" ]]; then
    #WKHTMLTOX_X64="https://packages.ubuntu.com/jammy/wkhtmltopdf"
    WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb"
    WKHTMLTOX_X32="https://packages.ubuntu.com/jammy/wkhtmltopdf"
    #No Same link works for both 64 and 32-bit on Ubuntu 22.04
else
    # For older versions of Ubuntu
    WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
    WKHTMLTOX_X32="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_i386.deb"
fi

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
echo "deb http://security.ubuntu.com/ubuntu focal-security main" | sudo tee /etc/apt/sources.list.d/focal-security.list
sudo apt-get update
sudo apt-get upgrade -y
sudo apt install libssl1.1 node-less python2-dev build-essential  libldap2-dev libsasl2-dev slapd ldap-utils tox valgrind libxml2-dev libxslt-dev

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
if [ $INSTALL_POSTGRESQL_FOURTEEN = "True" ]; then
    echo -e "\n---- Installing postgreSQL V14 due to the user it's choise ----"
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get install postgresql-14
else
    echo -e "\n---- Installing the default postgreSQL version 9.5 for Odoov10 ----"
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt install postgresql-9.5 -y
fi


echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  

  if [[ $(lsb_release -r -s) == "22.04" ]]; then
    # Ubuntu 22.04 LTS
    sudo apt install wkhtmltopdf -y
  else
      # For older versions of Ubuntu
    sudo gdebi --n `basename $_url`
  fi
  
  #sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  #sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION --single-branch https://www.github.com/odoo/odoo $OE_HOME_EXT/

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME_EXT/enterprise-addons"
sudo su $OE_USER -c "mkdir $OE_HOME/${OE_USER}-custom-addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 2.7 + pip --"
sudo apt install python2.7 python2.7-dev
sudo wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
sudo python2 get-pip.py
echo -e "\n--- Verify Python Version --"
sudo python2 -m pip --version
sudo python2 -m pip install virtualenv

echo -e "\n--- Create custo requirements file --"
cat <<EOF > ~/requirements_vmc.txt
asn1crypto ==1.4.0
Babel==2.3.4
backports-abc==0.5
backports.functools-lru-cache==1.6.4
backports.shutil-get-terminal-size==1.0.0
beautifulsoup4==4.6.0
bkcharts==0.2
bokeh==0.12.7
certifi==2021.10.8
cffi==1.14.6
chardet==3.0.4
cryptography==3.3.2
decorator==4.4.2
docopt==0.6.2
docutils==0.12
ebaysdk==2.1.4
enum34==1.1.10
feedparser==5.2.1
funcsigs==1.0.2
futures==3.3.0
gevent==1.1.2
google-api-python-client==1.6.6
greenlet==0.4.10
httplib2==0.11.3
idna==2.7
ipaddress==1.0.23
ipython==5.8.0
ipython-genutils==0.2.0
jcconv==0.2.3
Jinja2==2.8
lxml==4.6.3
Mako==1.0.4
MarkupSafe==0.23
mock==2.0.0
num2words==0.5.12
numpy==1.16.4
oauth2client==4.1.2
ofxparse==0.16
pandas==0.24.2
passlib==1.6.5
pathlib==1.0.1
pathlib2==2.3.4
pbr==3.1.1
pexpect==4.7.0
pg-xades==0.0.7
pg-xmlsig==0.0.3
phonenumbers==8.12.30
pickleshare==0.7.5
Pillow==3.4.1
pip==20.3.4
prompt-toolkit==1.0.16
psutil==4.3.1
psycogreen==1.0
psycopg2==2.7.3.1
ptyprocess==0.6.0
py4j==0.10.9.2
pyasn1==0.4.8
pyasn1-modules==0.2.8
pycparser==2.20
pydot==1.2.3
PyDrive==1.3.1
Pygments==2.4.2
pyldap==3.0.0
pyOpenSSL==20.0.1
pyparsing==2.1.10
pyPdf==1.13
pypng==0.0.20
PyQRCode==1.2.1
pyscopg2==66.0.2
pyserial==3.1.1
Python-Chart==1.39
python-dateutil==2.5.3
python-ldap==3.3.1
python-openid==2.2.5
python-stdnum==1.7
pytz==2021.1
pyusb==1.0.0
PyYAML==3.12
qrcode==5.3
reportlab==3.3.0
requests==2.11.1
rsa==3.4.2
scandir==1.10.0
setuptools==44.1.1
simplegeneric==0.8.1
singledispatch==3.4.0.3
six==1.16.0
soupsieve==1.9.6
suds-jurko==0.6
tornado==5.1.1
traitlets==4.3.2
uritemplate==3.0.0
urllib3==1.24.3
validators==0.14.2
vatnumber==1.2
vobject==0.9.3
wcwidth==0.1.7
Werkzeug==0.11.11
wheel==0.37.1
wkhtmltopdf==0.2
xlrd==1.0.0
XlsxWriter==0.9.3
xlwt==1.1.2
xmlsig==1.0.0
xmltodict==0.12.0
EOF
sudo mv ~/requirements_vmc.txt /$OE_HOME_EXT/requirements_vmc.txt
echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME


# Path to the virtual environment
venv_path="/$OE_HOME/$OE_USER-venv"
#Create a new Python virtual environment for Odoo
sudo su $OE_USER -c "python2 -m virtualenv $venv_path"
# Activate the virtual environment using sudo
echo -e "\n---- Install python packages/requirements ----"
sudo -H -u "$OE_USER" bash -c "source $venv_path/bin/activate && pip install wheel && pip install -r $OE_HOME_EXT/requirements.txt && pip install -r $OE_HOME_EXT/requirements_vmc.txt && deactivate"

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    sudo -H -u "$OE_USER" bash -c "source $venv_path/bin/activate && pip3 install psycopg2-binary pdfminer.six && deactivate"
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME_EXT/enterprise-addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME_EXT/enterprise-addons" 2>&1)
    done

    echo -e "\n---- Setting permissions on home folder ----"
    sudo chown -R $OE_USER:$OE_USER $OE_HOME
    echo -e "\n---- Added Enterprise code under $OE_HOME_EXT/enterprise-addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo -H -u "$OE_USER" bash -c "source $venv_path/bin/activate && pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL && deactivate"
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "* Create server config file"
sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
if [ $OE_VERSION > 11.0 ];then
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo su root -c "printf 'db_user = $OE_USER\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/${OE_USER}-custom-addons,${OE_HOME_EXT}/addons,${OE_HOME_EXT}/enterprise-addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME}/${OE_USER}-custom-addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
fi

echo -e "\n---- Setting permissions on config file ----"
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
#sudo apt-get install nodejs npm -y
#sudo npm install -g rtlcss


#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$OE_USER.service
[Unit]
Description=$OE_USER
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$OE_USER
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=$OE_HOME/$OE_USER-venv/bin/python2 $OE_HOME/$OE_CONFIG/odoo-bin -c /etc/$OE_CONFIG.conf
StandardOutput=journal+console
#Restart=always
#RestartSec=5


[Install]
WantedBy=multi-user.target
EOF

sudo mv ~/$OE_USER.service /etc/systemd/system/$OE_USER.service

#Notify systemd that a new unit file exists
sudo systemctl daemon-reload
#Start the Odoo service and enable it to start on boot by running:
sudo systemctl enable --now $OE_USER

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n---- Installing and setting up Nginx ----"
  sudo apt install nginx -y
  cat <<EOF > ~/odoo
server {
  listen 80;

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add Headers for odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    log files
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   force   timeouts    if  the backend dies
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
    text/less less;
    text/scss scss;
  }

  #   enable  data    compression
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
    proxy_pass    http://127.0.0.1:$OE_PORT;
    # by default, do not forward anything
    proxy_redirect off;
  }

  location /longpolling {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }

  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 2d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  # cache some static data in memory for 60mins.
  location ~ /[a-zA-Z0-9_-]*/static/ {
    proxy_cache_valid 200 302 60m;
    proxy_cache_valid 404      1m;
    proxy_buffering    on;
    expires 864000;
    proxy_pass    http://127.0.0.1:$OE_PORT;
  }
}
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/$WEBSITE_NAME
  sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
  sudo rm /etc/nginx/sites-enabled/default
  sudo service nginx reload
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/$WEBSITE_NAME"
else
  echo "Nginx isn't installed due to choice of the user!"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "_" ];then
  sudo apt-get update -y
  sudo apt install snapd -y
  sudo snap install core; snap refresh core
  sudo snap install --classic certbot
  sudo apt-get install python3-certbot-nginx -y
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo service nginx reload
  echo "SSL/HTTPS is enabled!"
else
  echo "SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration!"
  if $ADMIN_EMAIL = "odoo@example.com";then 
    echo "Certbot does not support registering odoo@example.com. You should use real e-mail address."
  fi
  if $WEBSITE_NAME = "_";then
    echo "Website name is set as _. Cannot obtain SSL Certificate for _. You should use real website address."
  fi
fi

echo -e "* Starting Odoo Service"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "Configuraton file location: /etc/${OE_CONFIG}.conf"
echo "Logfile location: /var/log/$OE_USER"
echo "User PostgreSQL: $OE_USER"
if [ $IS_ENTERPRISE = "True" ]; then
    echo "Code location:$OE_HOME_EXT"
    echo "Addons folder: $OE_HOME_EXT/addons/"
    echo "Enterprise Addons folder:$OE_HOME_EXT/enterprise-addons"  
else
    echo "Code location: $OE_HOME_EXT"
    echo "Addons folder: $OE_HOME_EXT/addons/"
fi
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "Start Odoo service: sudo service $OE_USER start"
echo "Stop Odoo service: sudo service $OE_USER stop"
echo "Restart Odoo service: sudo service $OE_USER restart"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/$WEBSITE_NAME"
fi
echo "-----------------------------------------------------------"
sudo systemctl status $OE_USER.service
