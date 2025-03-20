# Zabbix Server 7.0 LTS Installation Scripts

This repository contains scripts for automatic installation and configuration of Zabbix Server 7.0 LTS on Ubuntu 24.04 and RHEL 9.5 operating systems.

## Features

- Automatic installation of Zabbix Server 7.0 LTS
- PostgreSQL database configuration
- Nginx web server configuration
- Self-signed SSL certificate generation
- Security configuration (SSL/TLS, firewall)
- Support for two distributions: Ubuntu 24.04 and RHEL 9.5

## Requirements

### Ubuntu 24.04
- Minimum 2 GB RAM
- Minimum 20 GB free disk space
- Internet access for package downloads
- Root privileges

### RHEL 9.5
- Minimum 2 GB RAM
- Minimum 20 GB free disk space
- Internet access for package downloads
- Root privileges
- RHEL repository subscription (for package installation)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/zabbix-install-scripts.git
cd zabbix-install-scripts
```

2. Make scripts executable:
```bash
chmod +x install_zabbix_ubuntu.sh
chmod +x install_zabbix_rhel.sh
chmod +x install_zabbix_agent_ubuntu.sh
chmod +x install_zabbix_agent_rhel.sh
```

3. Select and run the appropriate script:

For installing Zabbix server on Ubuntu 24.04:
```bash
sudo ./install_zabbix_ubuntu.sh
```

For installing Zabbix server on RHEL 9.5:
```bash
sudo ./install_zabbix_rhel.sh
```

For installing Zabbix agent on Ubuntu 24.04:
```bash
sudo ./install_zabbix_agent_ubuntu.sh
```

For installing Zabbix agent on RHEL 9.5:
```bash
sudo ./install_zabbix_agent_rhel.sh
```

## Configuration

### Database and SSH Parameters
Before running the scripts, you can modify the following parameters at the beginning of each script:

For server installation scripts:
```bash
DB_NAME="zabbix"           # Database name
DB_USER="zabbix"           # Database user
DB_PASSWORD="zabbix_password"  # Database user password
POSTGRES_PASSWORD="postgres_password"  # PostgreSQL user password
SSH_PORT="22"              # Port for SSH access
```

For agent installation scripts:
```bash
ZABBIX_SERVER="zabbix.local"  # Zabbix server address
SSH_PORT="22"                 # SSH port
```

### After Installation

1. Add the following entry to `/etc/hosts`:
```
127.0.0.1 zabbix.local
```

2. Open in browser: https://zabbix.local

3. Login with default credentials:
- Username: Admin
- Password: zabbix

4. SSH access will be available on the port specified in the `SSH_PORT` variable (default 22)

## Security

- Scripts generate a self-signed SSL certificate valid for 1 year
- Firewall is configured (UFW for Ubuntu, FirewallD for RHEL)
- Basic Nginx security parameters are configured
- SSH access is configured (port is set via SSH_PORT variable)
- In production, it is recommended to:
  - Change default passwords
  - Configure a real SSL certificate
  - Set up additional security parameters
  - Change the default SSH port
  - Configure SSH key authentication instead of passwords

## Supported Versions

- Ubuntu 24.04 LTS
- RHEL 9.5

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

[Your Name]

## Support

If you encounter any issues, please create an issue in the project repository. 
