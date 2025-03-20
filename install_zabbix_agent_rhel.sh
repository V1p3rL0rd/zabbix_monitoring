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
dnf update -y

# Installing EPEL repository
echo "Installing EPEL repository..."
dnf install -y epel-release

# Adding Zabbix repository
echo "Adding Zabbix repository..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all
dnf makecache

# Installing Zabbix agent
echo "Installing Zabbix agent..."
dnf install -y zabbix-agent

# Configuring Zabbix agent
echo "Configuring Zabbix agent..."
sed -i "s/Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf

# SELinux configuration
echo "Configuring SELinux..."
semanage port -a -t ssh_port_t -p tcp $SSH_PORT
semanage port -a -t zabbix_agent_port_t -p tcp 10050

# Firewall configuration
echo "Configuring firewall..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --reload

# Enabling and starting service
echo "Enabling and starting Zabbix agent service..."
systemctl enable zabbix-agent
systemctl restart zabbix-agent

echo "Zabbix agent installation completed!"
echo "Agent is configured to connect to server: $ZABBIX_SERVER"
echo "SSH access is configured on port $SSH_PORT" 
