# Zabbix Server 7.0 LTS Installation Scripts

This repository contains scripts for automatic installation and configuration of Zabbix Server 7.0 LTS on Ubuntu 24.04 and RHEL/AlmaLinux 9.5 operating systems.

## Features

- Automatic installation of Zabbix Server 7.0 LTS
- MySQL database configuration
- Web server configuration (Apache/httpd)
- Self-signed SSL certificate generation
- Security configuration (SSL/TLS, firewall)
- Support for two distributions: Ubuntu 24.04 and RHEL 9.5

## Requirements

### Ubuntu 24.04
- Minimum 2 GB RAM
- Minimum 20 GB free disk space
- Internet access for package downloads
- Root privileges

### RHEL/AlmaLinux 9.5
- Minimum 2 GB RAM
- Minimum 20 GB free disk space
- Internet access for package downloads
- Root privileges
- RHEL repository subscription (for package installation)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/V1p3rL0rd/zabbix_monitoring.git
cd zabbix_monitoring
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

### Database and System Parameters
Before running the scripts, you can modify the following parameters at the beginning of each script:

```bash
mysql_db="zabbix"              # Database name
mysql_user="zabbix"            # Database user
mysql_pass="Pass_123"          # Database password
apache_cert_dir="/etc/ssl"     # SSL certificates directory
firewall_ports=("22/tcp" "443/tcp" "10051/tcp")  # Required ports
```

## After Installation

1. Open in browser: https://zabbix-server-IP/zabbix

2. Follow a few steps to complete the installation 

3. Login with default credentials:
- Username: Admin
- Password: zabbix

## Security Features

- Secure MySQL root password generation
- Protected password storage
- SSL certificate generation
- Firewall rules configuration
- Secure MySQL setup
- Self-signed SSL certificate valid for 1 year
- Firewall configuration (UFW for Ubuntu, FirewallD for RHEL)
- Basic web server security parameters

### Production Recommendations
- Change default passwords
- Configure a real SSL certificate
- Set up additional security parameters
- Configure SSH key authentication instead of passwords

## Supported Versions

- Ubuntu 24.04 LTS
- RHEL 9.5


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues, please:
1. Check the documentation
2. Review existing issues
3. Create a new issue if needed
