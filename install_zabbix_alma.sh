#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
   echo "Warning! This script must be run as root!"
   exit 1
fi

# Configuration variables
mysql_db="zabbix"
mysql_user="zabbix"  
mysql_pass="Pass_123" # Replace database password before running the script!
mysql_root_pass=$(openssl rand -base64 24)  # Generate secure password
apache_cert_dir="/etc/pki/tls/certs"
apache_key_dir="/etc/pki/tls/private"
firewall_ports=("22/tcp" "80/tcp" "443/tcp" "10051/tcp")  
timezone="Europe/Moscow"

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install EPEL repository
echo "Installing EPEL repository..."
dnf install -y epel-release

# Disable EPEL repository to avoid conflicts with Zabbix 7.0
dnf config-manager --set-disabled epel

# Add Zabbix repository
echo "Installing Zabbix repository..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all

# Install required packages
echo "Installing required packages..."
dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts \
               zabbix-agent mariadb-server httpd mod_ssl openssl php php-mysqlnd php-gd php-bcmath \
               php-ldap php-mbstring php-xml policycoreutils-python-utils

# Enable and start MariaDB
echo "Configuring MariaDB..."
systemctl enable --now mariadb

# Secure MariaDB installation
mysql_secure_installation <<EOF

y
${mysql_root_pass}
${mysql_root_pass}
y
y
y
y
EOF

# Create MySQL configuration file for root user access
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${mysql_root_pass}
EOF
chmod 600 /root/.my.cnf

# Save MySQL root password to file
echo "MySQL root password: ${mysql_root_pass}" > /root/mysql_root_password.txt
chmod 600 /root/mysql_root_password.txt

# Create database and user for Zabbix
echo "Creating database and user for Zabbix..."
mysql --defaults-extra-file=/root/.my.cnf <<EOF
CREATE DATABASE ${mysql_db} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '${mysql_user}'@'localhost' IDENTIFIED BY '${mysql_pass}';
GRANT ALL PRIVILEGES ON ${mysql_db}.* TO '${mysql_user}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import Zabbix database schema
echo "Importing Zabbix database schema..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --defaults-extra-file=/root/.my.cnf ${mysql_db}

# Configure Zabbix server
echo "Configuring Zabbix server..."
sed -i "s/^# DBPassword=.*/DBPassword=${mysql_pass}/" /etc/zabbix/zabbix_server.conf

# Generate self-signed SSL certificate
echo "Generating self-signed SSL certificate..."
mkdir -p ${apache_cert_dir} ${apache_key_dir}
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout ${apache_key_dir}/zabbix.key \
   -out ${apache_cert_dir}/zabbix.crt \
   -subj "/C=RU/ST=Moscow/L=Moscow/O=Company/CN=zabbix.local"

# Configure Apache SSL
echo "Configuring Apache SSL..."
cat > /etc/httpd/conf.d/zabbix-ssl.conf <<EOF
<VirtualHost *:443>
    SSLEngine on
    SSLCertificateFile ${apache_cert_dir}/zabbix.crt
    SSLCertificateKeyFile ${apache_key_dir}/zabbix.key
    
    DocumentRoot /usr/share/zabbix
    <Directory /usr/share/zabbix>
        Require all granted
        AllowOverride None
        Options FollowSymLinks
        
        <IfModule mod_php.c>
            php_value max_execution_time 300
            php_value memory_limit 128M
            php_value post_max_size 16M
            php_value upload_max_filesize 2M
            php_value max_input_time 300
            php_value date.timezone ${timezone}
        </IfModule>
    </Directory>
</VirtualHost>
EOF

# Configure PHP settings
echo "Configuring PHP settings..."
sed -i "s/^;*\s*date\.timezone\s*=.*/date.timezone = ${timezone}/" /etc/php.ini
sed -i "s/^max_execution_time = .*/max_execution_time = 300/" /etc/php.ini
sed -i "s/^memory_limit = .*/memory_limit = 128M/" /etc/php.ini
sed -i "s/^post_max_size = .*/post_max_size = 16M/" /etc/php.ini
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 2M/" /etc/php.ini

# Configure Firewall
echo "Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    for port in "${firewall_ports[@]}"; do
        firewall-cmd --permanent --add-port=${port}
    done
    firewall-cmd --reload
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

# Configure SELinux
echo "Configuring SELinux..."
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_connect_zabbix 1
setsebool -P zabbix_can_network 1
semanage port -a -t http_port_t -p tcp 10051 || true

# Fix file permissions
chown -R apache:apache /usr/share/zabbix

# Start and enable services
echo "Starting services..."
systemctl enable --now httpd zabbix-server zabbix-agent

# Final information
echo -e "\nZabbix has been successfully installed!"
echo "Web interface: https://$(hostname -f 2>/dev/null || curl -s ifconfig.me)/zabbix"
echo "Default credentials: Admin / zabbix"
echo -e "\nMySQL root password is stored in: /root/mysql_root_password.txt"
echo -e "\nDatabase parameters:"
echo "  Database: ${mysql_db}"
echo "  User: ${mysql_user}"
echo "  Password: ${mysql_pass}"
