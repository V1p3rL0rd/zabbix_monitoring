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
dnf update -y

# Installing EPEL repository
echo "Installing EPEL repository..."
dnf install -y epel-release

# Installing required packages
echo "Installing required packages..."
dnf install -y nginx postgresql-server postgresql-contrib php-fpm php-pgsql php-xml php-ldap php-gd php-curl php-mbstring php-bcmath php-zip php-gmp

# PostgreSQL initialization
echo "Initializing PostgreSQL..."
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# Adding Zabbix repository
echo "Adding Zabbix repository..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all
dnf makecache

# Installing Zabbix server and web interface
echo "Installing Zabbix server and web interface..."
dnf install -y zabbix-server-pgsql zabbix-web-pgsql-scl php-fpm

# PostgreSQL configuration
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
zcat /usr/share/doc/zabbix-server-pgsql*/create.sql.gz | sudo -u $DB_USER psql $DB_NAME

# PHP configuration
echo "Configuring PHP..."
sed -i 's/;date.timezone =/date.timezone = Europe\/Moscow/' /etc/php-fpm.d/www.conf
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php.ini

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
cat > /etc/nginx/conf.d/zabbix.conf << 'EOL'
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
        fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL

# SELinux configuration
echo "Configuring SELinux..."
setsebool -P httpd_can_connect_db on
setsebool -P httpd_can_network_connect on
semanage fcontext -a -t httpd_sys_content_t "/usr/share/zabbix(/.*)?"
restorecon -Rv /usr/share/zabbix

# SSH configuration in SELinux
echo "Configuring SSH in SELinux..."
semanage port -a -t ssh_port_t -p tcp $SSH_PORT

# Enabling and starting services
echo "Enabling and starting services..."
systemctl enable postgresql
systemctl enable php-fpm
systemctl enable zabbix-server
systemctl enable nginx
systemctl enable sshd

systemctl restart postgresql
systemctl restart php-fpm
systemctl restart zabbix-server
systemctl restart nginx
systemctl restart sshd

# Firewall configuration
echo "Configuring firewall..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --reload

echo "Installation completed!"
echo "Please add the following entry to /etc/hosts:"
echo "127.0.0.1 zabbix.local"
echo "Then open https://zabbix.local in your browser"
echo "Default login: Admin"
echo "Default password: zabbix"
echo "SSH access is configured on port $SSH_PORT" 
