#!/bin/bash

# Настройки
ZABBIX_SERVER="zabbix.local"  # Адрес сервера Zabbix
SSH_PORT="22"                 # Порт SSH

# Проверка на root права
if [ "$EUID" -ne 0 ]; then 
    echo "Пожалуйста, запустите скрипт с правами root"
    exit 1
fi

# Обновление системы
echo "Обновление системы..."
apt update && apt upgrade -y

# Добавление репозитория Zabbix
echo "Добавление репозитория Zabbix..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt update

# Установка Zabbix агента
echo "Установка Zabbix агента..."
apt install -y zabbix-agent

# Настройка Zabbix агента
echo "Настройка Zabbix агента..."
sed -i "s/Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf

# Настройка файрвола
echo "Настройка файрвола..."
ufw allow $SSH_PORT/tcp
ufw allow 10050/tcp
ufw --force enable

# Перезапуск сервиса
echo "Перезапуск сервиса Zabbix агента..."
systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "Установка Zabbix агента завершена!"
echo "Агент настроен на подключение к серверу: $ZABBIX_SERVER"
echo "SSH доступ настроен на порту $SSH_PORT" 
