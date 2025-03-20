#!/bin/bash

# Database settings
DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASSWORD="zabbix_password"
POSTGRES_PASSWORD="postgres_password"

# SSH settings
SSH_PORT="22"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run the script with root privileges"
    exit 1
fi

# System update
echo "Updating system..."
apt update && apt upgrade -y

# Installing required packages
echo "Installing required packages..."
apt install -y nginx postgresql postgresql-contrib php8.1-fpm php8.1-pgsql php8.1-xml php8.1-ldap php8.1-gd php8.1-curl php8.1-mbstring php8.1-bcmath php8.1-zip php8.1-gmp

# Adding Zabbix repository
echo "Adding Zabbix repository..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt update

# Installing Zabbix server and web interface
echo "Installing Zabbix server and web interface..."
apt install -y zabbix-server-pgsql zabbix-frontend-php php8.1-pgsql

# PostgreSQL configuration
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
zcat /usr/share/doc/zabbix-server-pgsql*/create.sql.gz | sudo -u $DB_USER psql $DB_NAME

# PHP configuration
echo "Configuring PHP..."
sed -i 's/;date.timezone =/date.timezone = Europe\/Moscow/' /etc/php/8.1/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini

# Zabbix server configuration
echo "Configuring Zabbix server..."
sed -i "s/# DBPassword=/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf
sed -i 's/# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf
sed -i "s/# DBName=zabbix/DBName=$DB_NAME/" /etc/zabbix/zabbix_server.conf
sed -i "s/# DBUser=zabbix/DBUser=$DB_USER/" /etc/zabbix/zabbix_server.conf

# SSL certificate generation
echo "Generating SSL certificate..."
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/zabbix.key \
    -out /etc/nginx/ssl/zabbix.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Zabbix/CN=zabbix.local"

# Nginx configuration
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/zabbix << 'EOL'
server {
    listen 443 ssl;
    server_name zabbix.local;

    ssl_certificate /etc/nginx/ssl/zabbix.crt;
    ssl_certificate_key /etc/nginx/ssl/zabbix.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /usr/share/zabbix;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL

ln -s /etc/nginx/sites-available/zabbix /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Restarting services
echo "Restarting services..."
systemctl restart postgresql
systemctl restart php8.1-fpm
systemctl restart zabbix-server
systemctl restart nginx

# Firewall configuration
echo "Configuring firewall..."
ufw allow $SSH_PORT/tcp
ufw allow 443/tcp
ufw allow 10051/tcp
ufw --force enable

echo "Installation completed!"
echo "Please add the following entry to /etc/hosts:"
echo "127.0.0.1 zabbix.local"
echo "Then open https://zabbix.local in your browser"
echo "Default login: Admin"
echo "Default password: zabbix"
echo "SSH access is configured on port $SSH_PORT" 
