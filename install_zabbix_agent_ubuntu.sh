#!/bin/bash

# Settings
ZABBIX_SERVER="zabbix.local"  # Zabbix server address
SSH_PORT="22"                 # SSH port

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run the script with root privileges"
    exit 1
fi

# System update
echo "Updating system..."
apt update && apt upgrade -y

# Adding Zabbix repository
echo "Adding Zabbix repository..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt update

# Installing Zabbix agent
echo "Installing Zabbix agent..."
apt install -y zabbix-agent

# Configuring Zabbix agent
echo "Configuring Zabbix agent..."
sed -i "s/Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf

# Firewall configuration
echo "Configuring firewall..."
ufw allow $SSH_PORT/tcp
ufw allow 10050/tcp
ufw --force enable

# Restarting service
echo "Restarting Zabbix agent service..."
systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "Zabbix agent installation completed!"
echo "Agent is configured to connect to server: $ZABBIX_SERVER"
echo "SSH access is configured on port $SSH_PORT" 
