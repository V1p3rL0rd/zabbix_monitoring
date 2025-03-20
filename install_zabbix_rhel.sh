#!/bin/bash

# Настройки базы данных
DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASSWORD="zabbix_password"
POSTGRES_PASSWORD="postgres_password"

# Настройки SSH
SSH_PORT="22"

# Проверка на root права
if [ "$EUID" -ne 0 ]; then 
    echo "Пожалуйста, запустите скрипт с правами root"
    exit 1
fi

# Обновление системы
echo "Обновление системы..."
dnf update -y

# Установка EPEL репозитория
echo "Установка EPEL репозитория..."
dnf install -y epel-release

# Установка необходимых пакетов
echo "Установка необходимых пакетов..."
dnf install -y nginx postgresql-server postgresql-contrib php-fpm php-pgsql php-xml php-ldap php-gd php-curl php-mbstring php-bcmath php-zip php-gmp

# Инициализация PostgreSQL
echo "Инициализация PostgreSQL..."
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# Добавление репозитория Zabbix
echo "Добавление репозитория Zabbix..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all
dnf makecache

# Установка Zabbix сервера и веб-интерфейса
echo "Установка Zabbix сервера и веб-интерфейса..."
dnf install -y zabbix-server-pgsql zabbix-web-pgsql-scl php-fpm

# Настройка PostgreSQL
echo "Настройка PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
zcat /usr/share/doc/zabbix-server-pgsql*/create.sql.gz | sudo -u $DB_USER psql $DB_NAME

# Настройка PHP
echo "Настройка PHP..."
sed -i 's/;date.timezone =/date.timezone = Europe\/Moscow/' /etc/php-fpm.d/www.conf
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php.ini

# Настройка Zabbix сервера
echo "Настройка Zabbix сервера..."
sed -i "s/# DBPassword=/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf
sed -i 's/# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf
sed -i "s/# DBName=zabbix/DBName=$DB_NAME/" /etc/zabbix/zabbix_server.conf
sed -i "s/# DBUser=zabbix/DBUser=$DB_USER/" /etc/zabbix/zabbix_server.conf

# Генерация SSL сертификата
echo "Генерация SSL сертификата..."
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/zabbix.key \
    -out /etc/nginx/ssl/zabbix.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Zabbix/CN=zabbix.local"

# Настройка Nginx
echo "Настройка Nginx..."
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

# Настройка SELinux
echo "Настройка SELinux..."
setsebool -P httpd_can_connect_db on
setsebool -P httpd_can_network_connect on
semanage fcontext -a -t httpd_sys_content_t "/usr/share/zabbix(/.*)?"
restorecon -Rv /usr/share/zabbix

# Настройка SSH в SELinux
echo "Настройка SSH в SELinux..."
semanage port -a -t ssh_port_t -p tcp $SSH_PORT

# Включение и запуск сервисов
echo "Включение и запуск сервисов..."
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

# Настройка файрвола
echo "Настройка файрвола..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --reload

echo "Установка завершена!"
echo "Пожалуйста, добавьте в /etc/hosts запись:"
echo "127.0.0.1 zabbix.local"
echo "После этого откройте https://zabbix.local в браузере"
echo "Логин по умолчанию: Admin"
echo "Пароль по умолчанию: zabbix"
echo "SSH доступ настроен на порту $SSH_PORT" 
