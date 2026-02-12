# MAAS for TrueNAS

![MAAS Logo](https://assets.ubuntu.com/v1/0de4fcd5-maas-logo.svg)

Deploy and manage bare metal infrastructure with MAAS (Metal as a Service) on TrueNAS 25.10+. This application provides automated server provisioning, lifecycle management, and infrastructure orchestration through a modern web UI and RESTful API.

## Overview

MAAS transforms your physical servers into a cloud-like infrastructure that you can provision in seconds. Designed for datacenter environments, edge computing, high-performance computing (HPC) clusters, and private cloud deployments, MAAS automates the entire server lifecycle from discovery to decommissioning.

### Key Features

- **Automated Server Discovery**: PXE boot enrollment with automatic hardware detection
- **Rapid OS Deployment**: Deploy Ubuntu, CentOS, RHEL, Windows, and custom images in under 2 minutes
- **Power Management**: Integrated IPMI, Redfish, and BMC control for remote power operations
- **Storage Configuration**: Automated RAID, LVM, ZFS, and bcache setup
- **Network Management**: DHCP, DNS, VLAN, and subnet management with traffic isolation
- **RESTful API**: Full OAuth-authenticated API for automation and integration
- **Cloud Integration**: Native support for Kubernetes, OpenStack, Terraform, and Ansible
- **High Availability**: Multi-region and multi-rack controller support for redundancy

### Use Cases

- **Private Cloud Infrastructure**: Build and manage your own cloud environment
- **HPC Clusters**: Rapid deployment of compute nodes for scientific computing
- **Edge Computing**: Centralized management of distributed bare metal infrastructure
- **CI/CD Infrastructure**: Automated provisioning of build and test servers
- **Kubernetes Clusters**: Provision bare metal Kubernetes worker nodes at scale
- **Development Environments**: On-demand provisioning of development and staging servers

## Requirements

### System Requirements

- **TrueNAS Version**: 25.10.0 or later (Goldeye release)
- **CPU**: 2 cores minimum (4 cores recommended)
- **Memory**: 4GB minimum (8GB recommended)
- **Storage**: 120GB minimum (250GB recommended)
- **Network**: Static IP address recommended

### Storage Requirements

| Component | Minimum | Recommended | Purpose |
|-----------|---------|-------------|---------|
| Config | 100MB | 1GB | Configuration files |
| Data | 10GB | 20GB | Application data |
| Images | 50GB | 100GB+ | OS boot images |
| Logs | 1GB | 5GB | Log files |
| Temp | 1GB | 5GB | Temporary files |
| PostgreSQL | 10GB | 20GB | Database storage |
| **Total** | **73GB** | **151GB+** | |

### Network Requirements

MAAS requires access to several network ports:

| Port | Protocol | Purpose | Required For |
|------|----------|---------|--------------|
| 5240 | TCP | HTTP UI/API | All deployments |
| 5443 | TCP | HTTPS UI/API | Optional (with TLS) |
| 69 | UDP | TFTP for PXE boot | Bare metal provisioning |
| 8000 | TCP | HTTP proxy | Image downloads |

## Installation

### Method 1: TrueNAS Web UI (Recommended)

1. **Navigate to Apps**
   - Open TrueNAS web interface
   - Go to Apps section
   - Search for "MAAS"

2. **Configure Application**
   - Click "Install"
   - Fill in required fields:
     - MAAS URL (e.g., `http://192.168.1.100:5240/MAAS`)
     - Admin username, password, and email
     - Database password
   - Choose storage dataset locations
   - Select network mode (host mode recommended for PXE boot)

3. **Deploy**
   - Click "Install"
   - Wait for deployment to complete (2-3 minutes)
   - Access MAAS UI at the configured URL

### Method 2: Manual Docker Compose Installation

1. **Clone Repository**
   ```bash
   git clone https://github.com/cpfarhood/truenas-maas-app.git
   cd truenas-maas-app
   ```

2. **Create Storage Directories**
   ```bash
   # Create all required directories
   sudo mkdir -p /mnt/tank/maas/{config,data,images,logs,tmp,postgres}

   # Set ownership to uid/gid 568 (required for non-root containers)
   sudo chown -R 568:568 /mnt/tank/maas/

   # Set permissions
   sudo chmod -R 755 /mnt/tank/maas/
   ```

3. **Configure Environment**
   ```bash
   # Copy example environment file
   cp .env.example .env

   # Edit .env file with your configuration
   nano .env
   ```

   Required variables in `.env`:
   ```bash
   MAAS_URL=http://192.168.1.100:5240/MAAS
   MAAS_ADMIN_USERNAME=admin
   MAAS_ADMIN_PASSWORD=your-secure-password-here
   MAAS_ADMIN_EMAIL=admin@example.com
   POSTGRES_PASSWORD=your-database-password-here
   ```

4. **Start Services**
   ```bash
   # Start MAAS and PostgreSQL
   docker compose up -d

   # Monitor startup logs
   docker compose logs -f
   ```

5. **Verify Deployment**
   ```bash
   # Check service status
   docker compose ps

   # Should show both services as healthy:
   # maas-postgres   Up (healthy)
   # maas-region     Up (healthy)
   ```

## Quick Start Guide

### 1. Access Web Interface

Open your browser and navigate to:
```
http://<truenas-ip>:5240/MAAS
```

Login with the credentials you configured during installation.

### 2. Import Boot Images

MAAS requires OS images before it can deploy machines:

1. Navigate to **Settings > Images**
2. Select Ubuntu releases to import (e.g., 22.04 LTS, 24.04 LTS)
3. Click **Import** and wait for download (10-30 minutes depending on selections)

Alternatively, via CLI:
```bash
docker compose exec maas bash
maas login admin http://localhost:5240/MAAS/api/2.0/
maas admin boot-resources import
maas admin boot-sources read
```

### 3. Configure Network Services

#### DNS Configuration
1. Go to **Settings > Network Services > DNS**
2. Set upstream DNS servers (e.g., 8.8.8.8, 8.8.4.4)
3. Configure DNS forwarder if managing DNS for your network

#### DHCP Configuration
For PXE boot to work, MAAS needs to manage DHCP:

1. Navigate to **Subnets**
2. Click on your network subnet
3. Click **Configure DHCP**
4. Set IP ranges for dynamic allocation
5. Set reserved ranges for existing infrastructure
6. Enable DHCP on the subnet

### 4. Enroll Physical Machines

#### Option A: Automatic Enrollment (PXE Boot)
1. Configure machine BIOS to boot from network (PXE/iPXE)
2. Ensure machine is on the same subnet as MAAS
3. Power on the machine
4. Machine will appear in MAAS UI as "New"
5. Commission and deploy as needed

#### Option B: Manual Enrollment (IPMI/BMC)
1. Navigate to **Machines > Add Hardware**
2. Select "Machine"
3. Enter machine details:
   - Hostname
   - Power type (IPMI, Redfish, etc.)
   - BMC IP address and credentials
4. Click "Save machine"
5. Commission and deploy

### 5. Deploy Your First Machine

1. Select a machine from the **Machines** list
2. Click **Actions > Commission** (if not already commissioned)
3. Wait for commissioning to complete
4. Click **Actions > Deploy**
5. Select OS and release (e.g., Ubuntu 24.04 LTS)
6. Configure storage and networking if needed
7. Click **Start deployment**
8. Machine will be ready in 2-5 minutes

## Configuration

### Network Mode Selection

#### Host Mode (Recommended for Production)
Use this for full MAAS functionality including PXE boot.

**Pros:**
- Required for PXE boot and DHCP functionality
- Direct access to host network
- No NAT overhead
- Best performance

**Cons:**
- No network isolation
- MAAS uses ports directly on host
- Potential port conflicts with other services

Configuration:
```bash
# In .env file
NETWORK_MODE=host
```

#### Bridge Mode (Testing/API-only)
Use this for testing or API-only deployments without PXE boot.

**Pros:**
- Network isolation
- Port mapping flexibility
- Multiple MAAS instances possible

**Cons:**
- PXE boot will not work
- NAT overhead
- More complex networking

Configuration:
```bash
# In .env file
NETWORK_MODE=bridge
MAAS_HTTP_PORT=5240
TFTP_PORT=69
```

### Environment Variables

#### Required Variables
- `MAAS_URL`: Full URL where MAAS will be accessible (must be reachable by managed machines)
- `MAAS_ADMIN_PASSWORD`: Administrator password (minimum 8 characters, 16+ recommended)
- `MAAS_ADMIN_EMAIL`: Administrator email address
- `POSTGRES_PASSWORD`: PostgreSQL password (minimum 8 characters, 16+ recommended)

#### Optional Variables
- `IMAGE_REPOSITORY`: Docker image repository (default: maasio/maas)
- `IMAGE_TAG`: MAAS version (default: 3.5)
- `NETWORK_MODE`: Network mode - host or bridge (default: host)
- `TZ`: Timezone (default: Etc/UTC)
- `MAAS_ADMIN_USERNAME`: Admin username (default: admin)
- `MAAS_DNS_FORWARDER`: DNS forwarder address (default: 8.8.8.8)
- `MAAS_BOOT_IMAGES_AUTO_IMPORT`: Auto-import boot images (default: true)

### Storage Configuration

Default storage paths (customizable via environment variables):
```bash
MAAS_CONFIG_PATH=/mnt/tank/maas/config
MAAS_DATA_PATH=/mnt/tank/maas/data
MAAS_IMAGES_PATH=/mnt/tank/maas/images
MAAS_LOGS_PATH=/mnt/tank/maas/logs
MAAS_TMP_PATH=/mnt/tank/maas/tmp
POSTGRES_DATA_PATH=/mnt/tank/maas/postgres
```

**Performance Tip**: Use SSD storage for config, data, and PostgreSQL. HDD is acceptable for boot images (large sequential reads).

## Usage Examples

### Web UI Operations

#### Managing Machines
1. **View All Machines**: Navigate to **Machines** tab
2. **Commission Machine**: Select machine > **Actions > Commission**
3. **Deploy Machine**: Select machine > **Actions > Deploy** > Choose OS
4. **Release Machine**: Select machine > **Actions > Release** (returns to pool)
5. **Power Control**: Select machine > **Take action > Power on/off**

#### Network Management
1. **Add Subnet**: **Subnets > Add subnet**
2. **Configure VLAN**: **Subnets > VLANs > Configure VLAN**
3. **Enable DHCP**: Select subnet > **Configure DHCP**
4. **Reserve IP**: Select subnet > **Reserved ranges > Reserve range**

### CLI Operations

Access MAAS CLI inside container:
```bash
docker compose exec maas bash
maas login admin http://localhost:5240/MAAS/api/2.0/
```

#### Machine Operations
```bash
# List all machines
maas admin machines read

# Commission a machine
maas admin machine commission <system-id>

# Deploy a machine
maas admin machine deploy <system-id> distro_series=jammy

# Release a machine
maas admin machine release <system-id>

# Get machine details
maas admin machine read <system-id>
```

#### Boot Image Management
```bash
# Import boot images
maas admin boot-resources import

# Check import status
maas admin boot-sources read

# List available images
maas admin boot-resources read
```

#### Network Operations
```bash
# List subnets
maas admin subnets read

# Create reserved IP range
maas admin ipranges create type=reserved \
  start_ip=192.168.1.100 end_ip=192.168.1.150 \
  subnet=<subnet-id>

# Enable DHCP on VLAN
maas admin vlan update <fabric-id> <vlan-id> dhcp_on=true
```

### API Integration

Generate API key:
1. Web UI > Account (top right) > API keys
2. Generate new API key
3. Copy the key for use in scripts

#### Python Example
```python
from maas.client import connect
import asyncio

async def main():
    client = await connect(
        "http://192.168.1.100:5240/MAAS/api/2.0/",
        apikey="your-api-key-here"
    )

    # List all machines
    machines = await client.machines.list()
    for machine in machines:
        print(f"{machine.hostname}: {machine.status_name}")

    # Deploy a machine
    machine = await client.machines.get(system_id="abc123")
    await machine.deploy(distro_series="jammy")

asyncio.run(main())
```

#### cURL Example
```bash
# Get API version
curl http://192.168.1.100:5240/MAAS/api/2.0/version/

# List machines (requires API key)
curl -H "Authorization: OAuth oauth_token=YOUR_API_KEY" \
  http://192.168.1.100:5240/MAAS/api/2.0/machines/
```

## Post-Installation Setup

### 1. Configure DNS Forwarder
If MAAS will provide DNS services:
1. Navigate to **Settings > Network Services > DNS**
2. Set upstream DNS servers (e.g., 8.8.8.8, 8.8.4.4)
3. Enable DNS forwarder

### 2. Import Additional Boot Images
Import OS images for your deployment needs:
1. Go to **Settings > Images**
2. Select additional releases or custom images
3. Click **Import**

### 3. Add SSH Keys
Add SSH keys for deployed machines:
1. Navigate to your **Account** (top right)
2. Go to **SSH keys**
3. Add your public SSH key
4. MAAS will inject this key into all deployed machines

### 4. Configure Power Management
Set up power control for your infrastructure:
1. Ensure BMC/IPMI is enabled on all machines
2. Configure network access to BMC interfaces
3. Test power control: **Machines > Select machine > Check power**

### 5. Set Up Storage Configuration
Configure default storage layouts:
1. Navigate to **Settings > Storage**
2. Define default disk layouts (flat, LVM, RAID, ZFS)
3. Set erasure policies for security

## Troubleshooting

### Services Won't Start

**Check logs:**
```bash
docker compose logs maas
docker compose logs postgres
```

**Common issues:**
- Storage paths don't exist or have wrong permissions
- Environment variables not set correctly
- Port conflicts with other services
- Insufficient disk space

**Solutions:**
```bash
# Verify storage paths
ls -la /mnt/tank/maas/

# Fix permissions
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/

# Check for port conflicts
netstat -tuln | grep -E '5240|69'

# Check disk space
df -h /mnt/tank/
```

### Database Connection Errors

**Symptoms:**
- MAAS logs show "could not connect to database"
- MAAS container keeps restarting

**Solutions:**
```bash
# Check PostgreSQL health
docker compose ps postgres

# Test database connection
docker compose exec postgres psql -U maas -d maasdb -c "SELECT version();"

# Verify password matches in .env
grep POSTGRES_PASSWORD .env

# Restart database
docker compose restart postgres
```

### PXE Boot Not Working

**Symptoms:**
- Machines fail to PXE boot
- TFTP timeouts

**Solutions:**
```bash
# Verify host network mode
docker inspect maas-region | grep NetworkMode
# Should show: "NetworkMode": "host"

# Check capabilities
docker inspect maas-region | grep -A 10 CapAdd

# Verify TFTP is accessible
netstat -uln | grep 69

# Test TFTP from another machine
tftp <maas-ip>
tftp> get version.txt
```

### Permission Denied Errors

**Symptoms:**
- "Permission denied" in logs
- Containers fail to write to volumes

**Solutions:**
```bash
# Check directory ownership
ls -la /mnt/tank/maas/
# Should show: drwxr-xr-x ... 1000 1000 ...

# Fix ownership
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/
```

### Out of Disk Space

**Check space usage:**
```bash
df -h /mnt/tank/
du -sh /mnt/tank/maas/*
```

**Solutions:**
```bash
# Remove old/unused boot images via MAAS UI
# Settings > Images > Select unused images > Delete

# Check log rotation is working
docker compose logs maas | head -20
```

### MAAS Web UI Not Accessible

**Verify MAAS is running:**
```bash
docker compose ps maas
docker inspect maas-region --format='{{.State.Health.Status}}'
```

**Test from container:**
```bash
docker compose exec maas curl -f http://localhost:5240/MAAS/
```

**Check firewall:**
```bash
# Ensure port 5240 is allowed
sudo iptables -L -n | grep 5240
```

## Backup and Restore

### Backup Procedure

```bash
#!/bin/bash
# backup-maas.sh

BACKUP_DIR="/mnt/tank/backups/maas"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/maas_backup_${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}"

echo "Starting MAAS backup..."

# Stop MAAS service (keep database running)
docker compose stop maas

# Backup database
echo "Backing up PostgreSQL database..."
docker compose exec -T postgres pg_dump -U maas maasdb | gzip > "${BACKUP_PATH}_database.sql.gz"

# Backup configuration and data volumes
echo "Backing up volumes..."
tar -czf "${BACKUP_PATH}_volumes.tar.gz" \
    /mnt/tank/maas/config \
    /mnt/tank/maas/data \
    /mnt/tank/maas/logs

# Restart MAAS service
docker compose start maas

echo "Backup completed: ${BACKUP_PATH}"
```

Make executable and schedule:
```bash
chmod +x backup-maas.sh

# Add to cron (daily at 2 AM)
crontab -e
0 2 * * * /path/to/backup-maas.sh
```

### Restore Procedure

```bash
#!/bin/bash
# restore-maas.sh

BACKUP_PATH="/mnt/tank/backups/maas/maas_backup_20260212_020000"

echo "Starting MAAS restore..."

# Stop all services
docker compose down

# Start PostgreSQL
docker compose up -d postgres
sleep 30

# Drop and recreate database
docker compose exec -T postgres psql -U maas -c "DROP DATABASE IF EXISTS maasdb;"
docker compose exec -T postgres psql -U maas -c "CREATE DATABASE maasdb;"

# Restore database
gunzip -c "${BACKUP_PATH}_database.sql.gz" | docker compose exec -T postgres psql -U maas maasdb

# Restore volumes
echo "Restoring volumes..."
tar -xzf "${BACKUP_PATH}_volumes.tar.gz" -C /

# Fix permissions
chown -R 568:568 /mnt/tank/maas/

# Start all services
docker compose up -d

echo "Restore completed"
```

## Operations

### Service Management

```bash
# View service status
docker compose ps

# View logs
docker compose logs -f maas
docker compose logs -f postgres

# Restart services
docker compose restart maas
docker compose restart postgres

# Stop all services
docker compose down

# Update to latest version
docker compose pull
docker compose up -d --force-recreate
```

### Health Monitoring

```bash
# Check health status
docker inspect maas-region --format='{{.State.Health.Status}}'
docker inspect maas-postgres --format='{{.State.Health.Status}}'

# View resource usage
docker stats maas-region maas-postgres

# Check disk usage
du -sh /mnt/tank/maas/*
```

## Security Best Practices

### 1. Strong Passwords

Generate secure passwords:
```bash
# Generate 32-character password
openssl rand -base64 32
```

### 2. Secure Environment File

```bash
# Set restrictive permissions
chmod 600 .env

# Never commit .env to git
echo ".env" >> .gitignore
```

### 3. Enable HTTPS

For production, use a reverse proxy with TLS:

**nginx example:**
```nginx
server {
    listen 443 ssl http2;
    server_name maas.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location /MAAS/ {
        proxy_pass http://localhost:5240/MAAS/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 4. Regular Updates

```bash
# Check for updates weekly
docker compose pull

# Apply updates
docker compose up -d --force-recreate
```

### 5. Network Isolation

Use firewall rules to restrict access:
```bash
# Allow only specific networks to access MAAS
sudo iptables -A INPUT -p tcp --dport 5240 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5240 -j DROP
```

### 6. Audit Logs

Monitor for suspicious activity:
```bash
# Review authentication logs
docker compose exec maas tail -f /var/log/maas/regiond.log | grep -i auth

# Review API access
docker compose exec maas tail -f /var/log/maas/regiond.log | grep -i api
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone repository
git clone https://github.com/cpfarhood/truenas-maas-app.git
cd truenas-maas-app

# Make changes
# Test changes
docker compose config
docker compose up -d

# Validate
./scripts/validate-compose.sh
```

### Reporting Issues

When reporting issues, please include:
1. TrueNAS version: `cat /etc/version`
2. Docker Compose version: `docker compose version`
3. Service logs: `docker compose logs`
4. Service status: `docker compose ps`
5. Environment (anonymized `.env` file)

## Documentation

### Official Resources
- **MAAS Documentation**: https://maas.io/docs
- **MAAS API Reference**: https://maas.io/docs/api
- **MAAS Discourse Community**: https://discourse.maas.io
- **TrueNAS Apps Documentation**: https://www.truenas.com/docs/truenasapps/
- **Docker Compose Reference**: https://docs.docker.com/compose/

### Project Documentation
- `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/DOCKER-COMPOSE-README.md` - Full deployment guide
- `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/DEPLOYMENT-CHECKLIST.md` - Pre/post-deployment checklist
- `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/QUICK-REFERENCE.md` - Quick reference card
- `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/.env.example` - Environment variable template

## License

This TrueNAS application configuration is licensed under the MIT License. See the LICENSE file for details.

MAAS itself is licensed under the AGPL-3.0 license by Canonical Ltd.

## Support

### Community Support
- **TrueNAS Forums**: https://forums.truenas.com/
- **MAAS Discourse**: https://discourse.maas.io
- **GitHub Issues**: https://github.com/cpfarhood/truenas-maas-app/issues

### Commercial Support
For enterprise support, contact:
- **Canonical (MAAS)**: https://ubuntu.com/support
- **iXsystems (TrueNAS)**: https://www.ixsystems.com/support/

## Acknowledgments

- **Canonical Ltd.** for MAAS development
- **iXsystems** for TrueNAS platform
- **TrueNAS Community** for feedback and testing

## Changelog

### Version 1.0.0 (2026-02-12)
- Initial release
- TrueNAS 25.10+ support
- MAAS 3.5 with PostgreSQL 15
- Host and bridge network modes
- Non-root container security
- Comprehensive health checks
- Full documentation suite

---

**Made with care for the TrueNAS community**
