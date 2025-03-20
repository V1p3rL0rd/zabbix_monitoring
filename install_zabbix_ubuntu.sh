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
mysql_root_pass=$(openssl rand -base64 24)  # Generate secure password and save to /root/mysql_root_password.txt
apache_cert_dir="/etc/ssl"
firewall_ports=("22/tcp" "443/tcp" "10051/tcp")  

# Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "Installing required packages..."
apt install -y wget gnupg2 software-properties-common

# Add Zabbix repository
echo "Installing Zabbix repository..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt update

# Install Zabbix and required packages
echo "Installing Zabbix and required packages..."
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent \
               mysql-server apache2 php php-mysql php-gd php-xml php-bcmath php-mbstring php-ldap php-zip

# Start MySQL
systemctl enable --now mysql

# Configure MySQL security
echo "Configuring MySQL security..."
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_pass}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create MySQL configuration file for root user access
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${mysql_root_pass}
EOF
chmod 600 /root/.my.cnf

# Save MySQL root password to file with restricted access (root only)
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
mkdir -p ${apache_cert_dir}/{certs,private}
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout ${apache_cert_dir}/private/zabbix.key \
   -out ${apache_cert_dir}/certs/zabbix.crt \
   -subj "/C=AB/ST=Sukhum Dist./L=Sukhum/O=SBRA/CN=zabbix.local"

# Configure SSL for Apache
echo "Configuring SSL for Apache..."
a2enmod ssl
a2enmod rewrite
cat > /etc/apache2/sites-available/zabbix.conf <<EOF
<VirtualHost *:443>
    ServerName zabbix.local
    DocumentRoot /usr/share/zabbix

    SSLEngine on
    SSLCertificateFile ${apache_cert_dir}/certs/zabbix.crt
    SSLCertificateKeyFile ${apache_cert_dir}/private/zabbix.key

    <Directory /usr/share/zabbix>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/zabbix_error.log
    CustomLog \${APACHE_LOG_DIR}/zabbix_access.log combined
</VirtualHost>
EOF

# Enable Zabbix site and disable default site
a2ensite zabbix.conf
a2dissite 000-default.conf

# Configure timezone
echo "Configuring timezone..."
sed -i "s/^;*\s*date\.timezone\s*=.*/date.timezone = Europe\/Moscow/" /etc/php/8.2/apache2/php.ini

# Configure Firewall
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
    for port in "${firewall_ports[@]}"; do
        ufw allow ${port}
    done
    ufw --force enable
fi

# Start services
echo "Starting services..."
systemctl enable --now apache2 zabbix-server zabbix-agent

# Final information
echo "Zabbix has been successfully installed!"
echo "To access the web interface: https://$(hostname -f)/zabbix"
echo "MySQL root password is stored in: /root/mysql_root_password.txt"
echo "Database parameters:"
echo "  Database: ${mysql_db}"
echo "  User: ${mysql_user}"
echo "  Password: ${mysql_pass}" 
