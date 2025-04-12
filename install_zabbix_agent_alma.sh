#!/bin/bash

# Settings
ZABBIX_SERVER="zabbix.local"  # Zabbix server address
SSH_PORT="22"                 # SSH port
HOSTNAME=$(hostname -f)       # Get system hostname

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run the script with root privileges"
    exit 1
fi

# System update
echo "Updating system packages..."
dnf update -y

# Installing EPEL repository
echo "Installing EPEL repository..."
dnf install -y epel-release

# Adding Zabbix repository
echo "Adding Zabbix repository..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all
dnf makecache

# Installing Zabbix agent and dependencies
echo "Installing Zabbix agent..."
dnf install -y zabbix-agent zabbix-selinux-policy policycoreutils-python-utils

# Configuring Zabbix agent
echo "Configuring Zabbix agent..."
cat > /etc/zabbix/zabbix_agentd.conf <<EOF
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=${ZABBIX_SERVER}
ServerActive=${ZABBIX_SERVER}
Hostname=${HOSTNAME}
Include=/etc/zabbix/zabbix_agentd.d/*.conf
EOF

# Create custom hostname file if needed
if [ "$HOSTNAME" != "$(hostname -s)" ]; then
    echo "HostnameItem=system.run[hostname -f]" > /etc/zabbix/zabbix_agentd.d/hostname.conf
fi

# SELinux configuration
echo "Configuring SELinux..."
if command -v semanage >/dev/null 2>&1; then
    semanage port -a -t ssh_port_t -p tcp $SSH_PORT || true
    semanage port -a -t zabbix_agent_port_t -p tcp 10050 || true
    setsebool -P zabbix_can_network=1
else
    echo "semanage not found, skipping SELinux port configuration"
fi

# Firewall configuration
echo "Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
    firewall-cmd --permanent --add-port=10050/tcp
    firewall-cmd --reload
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

# Enabling and starting service
echo "Starting Zabbix agent service..."
systemctl enable --now zabbix-agent

# Verify service status
if systemctl is-active --quiet zabbix-agent; then
    echo -e "\nZabbix agent installation completed successfully!"
    echo "Agent is configured to connect to server: ${ZABBIX_SERVER}"
    echo "Hostname configured as: ${HOSTNAME}"
    echo "SSH access is configured on port ${SSH_PORT}"
    echo -e "\nAgent status: $(systemctl is-active zabbix-agent)"
else
    echo -e "\nWarning: Zabbix agent service failed to start!"
    echo "Please check logs: journalctl -u zabbix-agent"
    exit 1
fi
