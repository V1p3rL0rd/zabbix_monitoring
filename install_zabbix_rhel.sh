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
apache_cert_dir="/etc/pki/tls"
firewall_ports=("22/tcp" "443/tcp" "10051/tcp")  

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install EPEL repository
echo "Installing EPEL repository..."
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# Disable EPEL repository to avoid conflicts with Zabbix 7.0
dnf config-manager --set-disabled epel

# Add Zabbix repository
echo "Installing Zabbix repository..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm

# Install required packages
echo "Installing required packages..."
dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-agent \
               mysql-server httpd mod_ssl openssl php php-mysqlnd

# Start MySQL
systemctl enable --now mysqld

# Configure MySQL security
echo "Configuring MySQL security..."
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_pass}';
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
sed -i "s|^SSLCertificateFile .*|SSLCertificateFile ${apache_cert_dir}/certs/zabbix.crt|" /etc/httpd/conf.d/ssl.conf
sed -i "s|^SSLCertificateKeyFile .*|SSLCertificateKeyFile ${apache_cert_dir}/private/zabbix.key|" /etc/httpd/conf.d/ssl.conf

# Configure timezone
echo "Configuring timezone..."
sed -i "s/^;*\s*date\.timezone\s*=.*/date.timezone = Europe\/Moscow/" /etc/php.ini

# Configure Firewall
echo "Configuring firewall..."
for port in "${firewall_ports[@]}"; do
   firewall-cmd --permanent --add-port=${port}
done
firewall-cmd --reload

# Configure SELinux
echo "Configuring SELinux..."
# Allow Apache to use network connections
setsebool -P httpd_can_network_connect 1
# Allow Zabbix to use network connections
setsebool -P zabbix_can_network 1
# Allow Zabbix server to listen on port 10051
semanage port -a -t zabbix_port_t -p tcp 10051

# Start Zabbix services
echo "Starting Zabbix services..."
systemctl enable --now httpd zabbix-server zabbix-agent

# Final information
echo "Zabbix has been successfully installed!"
echo "To access the web interface: https://$(hostname -f)/zabbix"
echo "MySQL root password is stored in: /root/mysql_root_password.txt"
echo "Database parameters:"
echo "  Database: ${mysql_db}"
echo "  User: ${mysql_user}"
echo "  Password: ${mysql_pass}" 
