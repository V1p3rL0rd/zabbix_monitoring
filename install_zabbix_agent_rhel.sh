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
dnf update -y

# Установка EPEL репозитория
echo "Установка EPEL репозитория..."
dnf install -y epel-release

# Добавление репозитория Zabbix
echo "Добавление репозитория Zabbix..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all
dnf makecache

# Установка Zabbix агента
echo "Установка Zabbix агента..."
dnf install -y zabbix-agent

# Настройка Zabbix агента
echo "Настройка Zabbix агента..."
sed -i "s/Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf

# Настройка SELinux
echo "Настройка SELinux..."
semanage port -a -t ssh_port_t -p tcp $SSH_PORT
semanage port -a -t zabbix_agent_port_t -p tcp 10050

# Настройка файрвола
echo "Настройка файрвола..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --reload

# Включение и запуск сервиса
echo "Включение и запуск сервиса Zabbix агента..."
systemctl enable zabbix-agent
systemctl restart zabbix-agent

echo "Установка Zabbix агента завершена!"
echo "Агент настроен на подключение к серверу: $ZABBIX_SERVER"
echo "SSH доступ настроен на порту $SSH_PORT" 
