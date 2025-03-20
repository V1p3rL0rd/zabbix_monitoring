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
apt update && apt upgrade -y

# Установка необходимых пакетов
echo "Установка необходимых пакетов..."
apt install -y nginx postgresql postgresql-contrib php8.1-fpm php8.1-pgsql php8.1-xml php8.1-ldap php8.1-gd php8.1-curl php8.1-mbstring php8.1-bcmath php8.1-zip php8.1-gmp

# Добавление репозитория Zabbix
echo "Добавление репозитория Zabbix..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt update

# Установка Zabbix сервера и веб-интерфейса
echo "Установка Zabbix сервера и веб-интерфейса..."
apt install -y zabbix-server-pgsql zabbix-frontend-php php8.1-pgsql

# Настройка PostgreSQL
echo "Настройка PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
zcat /usr/share/doc/zabbix-server-pgsql*/create.sql.gz | sudo -u $DB_USER psql $DB_NAME

# Настройка PHP
echo "Настройка PHP..."
sed -i 's/;date.timezone =/date.timezone = Europe\/Moscow/' /etc/php/8.1/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini

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

# Перезапуск сервисов
echo "Перезапуск сервисов..."
systemctl restart postgresql
systemctl restart php8.1-fpm
systemctl restart zabbix-server
systemctl restart nginx

# Настройка файрвола
echo "Настройка файрвола..."
ufw allow $SSH_PORT/tcp
ufw allow 443/tcp
ufw allow 10051/tcp
ufw --force enable

echo "Установка завершена!"
echo "Пожалуйста, добавьте в /etc/hosts запись:"
echo "127.0.0.1 zabbix.local"
echo "После этого откройте https://zabbix.local в браузере"
echo "Логин по умолчанию: Admin"
echo "Пароль по умолчанию: zabbix"
echo "SSH доступ настроен на порту $SSH_PORT" 
