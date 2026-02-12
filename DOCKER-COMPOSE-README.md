# MAAS Docker Compose Deployment Guide

This guide provides detailed instructions for deploying MAAS (Metal as a Service) on TrueNAS 25.10+ using Docker Compose.

## Overview

This Docker Compose configuration deploys a production-ready MAAS environment consisting of:

- **MAAS Region Controller**: Web UI, API, and infrastructure management
- **PostgreSQL Database**: Persistent data storage for MAAS

Both services run as non-root (uid/gid 568) and include comprehensive health checks, logging, and security hardening.

## Prerequisites

### System Requirements

- **TrueNAS Version**: 25.10.0 or later (required for modern Docker Compose features)
- **Memory**: Minimum 4GB RAM allocated to Docker
- **Storage**: Minimum 135GB (see Storage Requirements below)
- **Network**: Static IP address recommended for MAAS server

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

- **Port 5240/tcp**: HTTP API/UI (configurable)
- **Port 5443/tcp**: HTTPS API/UI (optional)
- **Port 69/udp**: TFTP for PXE boot (required for bare metal provisioning)
- **Port 8000/tcp**: HTTP proxy for image downloads

## Installation

### Step 1: Create Storage Directories

Create the required storage directories on your TrueNAS pool:

```bash
# Create all directories
sudo mkdir -p /mnt/tank/maas/{config,data,images,logs,tmp,postgres}

# Set ownership to uid/gid 568 (required for non-root containers)
sudo chown -R 568:568 /mnt/tank/maas/

# Set permissions
sudo chmod -R 755 /mnt/tank/maas/
```

**Recommended TrueNAS Dataset Structure:**

```
pool: tank
└── dataset: maas
    ├── config (dataset)
    ├── data (dataset)
    ├── images (dataset) <- Large, consider HDD storage
    ├── logs (dataset)
    ├── tmp (dataset)
    └── postgres (dataset) <- Use SSD storage for performance
```

### Step 2: Configure Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` and set the required variables:

```bash
# REQUIRED: MAAS server URL (must be accessible from managed machines)
MAAS_URL=http://192.168.1.100:5240/MAAS

# REQUIRED: Administrator credentials
MAAS_ADMIN_USERNAME=admin
MAAS_ADMIN_PASSWORD=your-secure-password-here
MAAS_ADMIN_EMAIL=admin@example.com

# REQUIRED: Database password
POSTGRES_PASSWORD=your-database-password-here

# OPTIONAL: Adjust storage paths if needed
MAAS_CONFIG_PATH=/mnt/tank/maas/config
MAAS_DATA_PATH=/mnt/tank/maas/data
MAAS_IMAGES_PATH=/mnt/tank/maas/images
MAAS_LOGS_PATH=/mnt/tank/maas/logs
MAAS_TMP_PATH=/mnt/tank/maas/tmp
POSTGRES_DATA_PATH=/mnt/tank/maas/postgres
```

**Security Note**: Protect your `.env` file:

```bash
chmod 600 .env
```

### Step 3: Choose Network Mode

#### Option A: Host Network Mode (Recommended for Production)

**Use this for full MAAS functionality including PXE boot.**

```bash
# In .env file
NETWORK_MODE=host
```

**Pros:**
- Required for PXE boot and DHCP functionality
- Direct access to host network
- No NAT overhead
- Best performance

**Cons:**
- No network isolation
- MAAS uses ports directly on host
- Potential port conflicts with other services

#### Option B: Bridge Network Mode (Testing/API-only)

**Use this for testing or API-only deployments without PXE boot.**

```bash
# In .env file
NETWORK_MODE=bridge
MAAS_HTTP_PORT=5240
TFTP_PORT=69
```

**Pros:**
- Network isolation
- Port mapping flexibility
- Multiple MAAS instances possible

**Cons:**
- PXE boot will not work
- NAT overhead
- More complex networking

### Step 4: Start Services

```bash
# Start all services in detached mode
docker compose up -d

# Monitor startup logs
docker compose logs -f
```

**Expected startup sequence:**

1. PostgreSQL starts and initializes database (~30 seconds)
2. PostgreSQL health check passes
3. MAAS starts and connects to database (~60-90 seconds)
4. MAAS completes initialization and becomes healthy

### Step 5: Verify Deployment

```bash
# Check service status
docker compose ps

# Expected output:
# NAME            STATUS         HEALTH
# maas-postgres   Up (healthy)   healthy
# maas-region     Up (healthy)   healthy

# Check logs for any errors
docker compose logs maas | grep -i error
docker compose logs postgres | grep -i error
```

### Step 6: Access MAAS Web UI

Open your browser and navigate to:

```
http://<truenas-ip>:5240/MAAS
```

Login with the credentials specified in your `.env` file:
- Username: `admin` (or your configured username)
- Password: Your configured `MAAS_ADMIN_PASSWORD`

## Post-Installation Configuration

### 1. Import Boot Images

MAAS requires OS boot images to deploy machines. Import them via the web UI or CLI:

**Via Web UI:**
1. Navigate to Settings → Images
2. Select Ubuntu releases to import (e.g., 22.04 LTS, 24.04 LTS)
3. Click "Import" and wait for download to complete (~10-30 minutes depending on selections)

**Via CLI:**

```bash
# Enter MAAS container
docker compose exec maas bash

# Login to MAAS
maas login admin http://localhost:5240/MAAS/api/2.0/

# Import Ubuntu images
maas admin boot-resources import

# Check import status
maas admin boot-sources read
```

### 2. Configure DNS Forwarder

If MAAS will provide DNS services:

1. Navigate to Settings → Network Services → DNS
2. Set upstream DNS servers (e.g., 8.8.8.8, 8.8.4.4)
3. Configure DNS forwarder if needed

### 3. Configure Subnets and DHCP

For PXE boot to work, MAAS needs to manage DHCP:

1. Navigate to Subnets
2. Click on your network subnet
3. Click "Configure DHCP"
4. Set IP ranges for dynamic allocation
5. Set reserved ranges (e.g., for existing infrastructure)
6. Enable DHCP on the subnet

### 4. Enroll Physical Machines

**Option A: Automatic Enrollment (PXE Boot)**
1. Configure machine BIOS to boot from network (PXE)
2. Ensure machine is on same subnet as MAAS
3. Power on machine
4. Machine will appear in MAAS UI as "New"
5. Commission and deploy as needed

**Option B: Manual Enrollment (IPMI/BMC)**
1. Navigate to Machines → Add Hardware
2. Select "Machine"
3. Enter machine details (hostname, power type, BMC credentials)
4. Click "Save machine"
5. Commission and deploy

## Operations

### Starting and Stopping Services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart a specific service
docker compose restart maas
docker compose restart postgres

# View service logs
docker compose logs -f maas
docker compose logs -f postgres

# View logs from specific time
docker compose logs --since 30m maas
```

### Health Monitoring

```bash
# Check health status
docker compose ps

# Detailed health check
docker inspect maas-region --format='{{.State.Health.Status}}'
docker inspect maas-postgres --format='{{.State.Health.Status}}'

# View health check logs
docker inspect maas-region --format='{{json .State.Health}}' | jq
```

### Resource Usage

```bash
# View resource consumption
docker stats maas-region maas-postgres

# View disk usage
du -sh /mnt/tank/maas/*
```

### Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate

# Clean up old images
docker image prune -a
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

# Optionally backup boot images (large, may skip if re-importable)
# tar -czf "${BACKUP_PATH}_images.tar.gz" /mnt/tank/maas/images

# Restart MAAS service
docker compose start maas

echo "Backup completed: ${BACKUP_PATH}"
```

**Schedule with cron:**

```bash
# Edit crontab
crontab -e

# Add backup job (daily at 2 AM)
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

# Restore database
echo "Restoring PostgreSQL database..."
docker compose up -d postgres
sleep 30  # Wait for PostgreSQL to start

# Drop and recreate database
docker compose exec -T postgres psql -U maas -c "DROP DATABASE IF EXISTS maasdb;"
docker compose exec -T postgres psql -U maas -c "CREATE DATABASE maasdb;"

# Restore database dump
gunzip -c "${BACKUP_PATH}_database.sql.gz" | docker compose exec -T postgres psql -U maas maasdb

# Restore volumes
echo "Restoring volumes..."
tar -xzf "${BACKUP_PATH}_volumes.tar.gz" -C /

# Restore images (if backed up)
# tar -xzf "${BACKUP_PATH}_images.tar.gz" -C /

# Fix permissions
chown -R 568:568 /mnt/tank/maas/

# Start all services
docker compose up -d

echo "Restore completed"
```

## Troubleshooting

### Services Won't Start

**Check logs:**
```bash
docker compose logs
```

**Common issues:**
- Storage paths don't exist or have wrong permissions
- Environment variables not set correctly
- Port conflicts with other services
- Insufficient disk space

**Solutions:**
```bash
# Verify storage paths exist
ls -la /mnt/tank/maas/

# Fix permissions
sudo chown -R 568:568 /mnt/tank/maas/

# Check for port conflicts
netstat -tuln | grep -E '5240|69'

# Check disk space
df -h /mnt/tank/
```

### Database Connection Errors

**Symptoms:**
- MAAS logs show "could not connect to database"
- MAAS container keeps restarting

**Check PostgreSQL health:**
```bash
docker compose ps postgres
docker compose logs postgres
```

**Test database connection:**
```bash
docker compose exec postgres psql -U maas -d maasdb -c "SELECT version();"
```

**Verify password matches:**
```bash
# Check POSTGRES_PASSWORD is consistent in .env file
grep POSTGRES_PASSWORD .env
```

### PXE Boot Not Working

**Symptoms:**
- Machines fail to PXE boot
- TFTP timeouts

**Check network mode:**
```bash
# Must be in host mode for PXE
docker inspect maas-region | grep NetworkMode
# Should show: "NetworkMode": "host"
```

**Verify TFTP is accessible:**
```bash
# From another machine on the network
tftp <maas-ip>
tftp> get version.txt
```

**Check firewall rules:**
```bash
# Ensure UDP port 69 is allowed
sudo iptables -L -n | grep 69
```

**Verify capabilities:**
```bash
# MAAS needs NET_ADMIN and NET_RAW
docker inspect maas-region | grep -A 10 CapAdd
```

### Permission Denied Errors

**Symptoms:**
- "Permission denied" in logs
- Containers fail to write to volumes

**Check directory ownership:**
```bash
ls -la /mnt/tank/maas/
# Should show: drwxr-xr-x ... 1000 1000 ...
```

**Fix ownership:**
```bash
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/
```

### Out of Disk Space

**Check space usage:**
```bash
df -h /mnt/tank/
du -sh /mnt/tank/maas/*
```

**Clean up boot images:**
```bash
# Remove old/unused images via MAAS UI
# Settings → Images → Select unused images → Delete
```

**Rotate logs:**
```bash
# Logs are already configured with rotation in compose.yaml
# Manually truncate if needed
docker compose exec maas truncate -s 0 /var/log/maas/*.log
```

### MAAS Web UI Not Accessible

**Verify MAAS is running:**
```bash
docker compose ps maas
```

**Check health:**
```bash
docker inspect maas-region --format='{{.State.Health.Status}}'
```

**Test from container:**
```bash
docker compose exec maas curl -f http://localhost:5240/MAAS/
```

**Check host firewall:**
```bash
# Ensure port 5240 is allowed
sudo iptables -L -n | grep 5240
```

## Security Best Practices

### 1. Strong Passwords

Generate secure passwords:
```bash
# Generate 32-character password
openssl rand -base64 32
```

### 2. Secure .env File

```bash
# Set restrictive permissions
chmod 600 .env

# Verify
ls -la .env
# Should show: -rw------- ... .env
```

### 3. Network Isolation

If using bridge mode, restrict access:

```yaml
# Add to compose.yaml under maas service
networks:
  - maas-internal

# Create custom network with access control
```

### 4. HTTPS/TLS

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

### 5. Regular Updates

```bash
# Check for updates weekly
docker compose pull

# Apply updates
docker compose up -d --force-recreate
```

### 6. Audit Logs

Monitor for suspicious activity:
```bash
# Review authentication logs
docker compose exec maas tail -f /var/log/maas/regiond.log | grep -i auth

# Review API access
docker compose exec maas tail -f /var/log/maas/regiond.log | grep -i api
```

### 7. Backup Encryption

Encrypt backups at rest:
```bash
# Encrypt backup with GPG
gpg --symmetric --cipher-algo AES256 maas_backup.tar.gz
```

## Performance Tuning

### PostgreSQL Optimization

For better database performance, tune PostgreSQL settings:

```bash
# Edit compose.yaml and add environment variables
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_WORK_MEM=16MB
POSTGRES_MAINTENANCE_WORK_MEM=128MB
```

### Storage Performance

- **PostgreSQL**: Use SSD storage for database
- **Boot Images**: Can use HDD storage (large sequential reads)
- **Config/Data**: Use SSD for better responsiveness

### Resource Limits

Add resource limits to prevent resource exhaustion:

```yaml
# Add to services in compose.yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 4G
    reservations:
      cpus: '1.0'
      memory: 2G
```

## Advanced Configuration

### Multi-Node MAAS (Region + Rack Controllers)

For production environments, deploy separate rack controllers:

1. Deploy region controller using this compose file
2. Get region secret: `docker compose exec maas cat /var/lib/maas/secret`
3. Deploy rack controllers with `MAAS_REGION_SECRET` set

### Integration with TrueNAS Storage

Configure MAAS to mount TrueNAS NFS/iSCSI storage on deployed machines:

```bash
# In MAAS cloud-init user data
#cloud-config
mounts:
  - [ "truenas-nfs:/mnt/share", "/mnt/storage", "nfs", "defaults", "0", "0" ]
```

### API Integration

Use MAAS API for automation:

```python
from maas.client import connect
import asyncio

async def main():
    client = await connect(
        "http://192.168.1.100:5240/MAAS/api/2.0/",
        apikey="your-api-key"
    )

    machines = await client.machines.list()
    for machine in machines:
        print(f"{machine.hostname}: {machine.status_name}")

asyncio.run(main())
```

## Support and Resources

### Documentation

- **MAAS Documentation**: https://maas.io/docs
- **TrueNAS Apps**: https://www.truenas.com/docs/truenasapps/
- **Docker Compose**: https://docs.docker.com/compose/

### Community

- **MAAS Discourse**: https://discourse.maas.io
- **TrueNAS Forums**: https://forums.truenas.com/
- **GitHub Issues**: https://github.com/yourusername/truenas-maas-app

### Getting Help

When requesting help, provide:
1. TrueNAS version: `cat /etc/version`
2. Docker Compose version: `docker compose version`
3. Service logs: `docker compose logs`
4. Service status: `docker compose ps`
5. Environment (anonymized .env file)

## License

This Docker Compose configuration is licensed under MIT License.

MAAS itself is licensed under AGPL-3.0 by Canonical Ltd.
