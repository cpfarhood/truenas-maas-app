# MAAS Docker Compose Deployment Checklist

This checklist ensures all prerequisites are met before deploying MAAS on TrueNAS 25.10+.

## Pre-Deployment Checklist

### System Requirements

- [ ] **TrueNAS Version**: 25.10.0 or later
  ```bash
  cat /etc/version
  ```

- [ ] **Docker Available**: Docker Compose v2.x
  ```bash
  docker --version
  docker compose version
  ```

- [ ] **Memory**: Minimum 4GB RAM allocated to Docker
  ```bash
  free -h
  ```

- [ ] **Storage**: Minimum 135GB available
  ```bash
  df -h /mnt/tank
  ```

### Network Configuration

- [ ] **Static IP**: MAAS server has static IP address
  ```bash
  ip addr show
  ```

- [ ] **DNS Resolution**: Hostname resolves correctly
  ```bash
  nslookup $(hostname)
  ```

- [ ] **Port Availability**: Required ports are free (if using bridge mode)
  ```bash
  netstat -tuln | grep -E '5240|5443|69'
  ```

- [ ] **Firewall Rules**: Ports allowed through firewall
  ```bash
  # Port 5240/tcp - HTTP UI/API
  # Port 5443/tcp - HTTPS UI/API (optional)
  # Port 69/udp - TFTP (PXE boot)
  # Port 8000/tcp - HTTP proxy
  ```

### Storage Preparation

- [ ] **Base Directory Created**: `/mnt/tank/maas` or custom path
  ```bash
  mkdir -p /mnt/tank/maas
  ```

- [ ] **Subdirectories Created**: All required directories exist
  ```bash
  mkdir -p /mnt/tank/maas/{config,data,images,logs,tmp,postgres}
  ```

- [ ] **Permissions Set**: Directories owned by uid/gid 1000
  ```bash
  sudo chown -R 1000:1000 /mnt/tank/maas/
  sudo chmod -R 755 /mnt/tank/maas/
  ```

- [ ] **Ownership Verified**: Check ownership is correct
  ```bash
  ls -la /mnt/tank/maas/
  # Should show: drwxr-xr-x ... 1000 1000 ...
  ```

### Configuration Files

- [ ] **compose.yaml Exists**: Docker Compose file present
  ```bash
  ls -la /path/to/compose.yaml
  ```

- [ ] **.env File Created**: Environment file configured
  ```bash
  cp .env.example .env
  ```

- [ ] **Required Variables Set**: All mandatory variables configured
  - [ ] `MAAS_URL` - Full URL (e.g., http://192.168.1.100:5240/MAAS)
  - [ ] `MAAS_ADMIN_PASSWORD` - Strong password (16+ chars)
  - [ ] `MAAS_ADMIN_EMAIL` - Valid email address
  - [ ] `POSTGRES_PASSWORD` - Strong password (16+ chars)

- [ ] **Optional Variables Reviewed**: Customize if needed
  - [ ] `NETWORK_MODE` - host (default) or bridge
  - [ ] `TZ` - Timezone (default: Etc/UTC)
  - [ ] Storage paths (default: /mnt/tank/maas/*)

- [ ] **.env Permissions Secured**: File readable only by owner
  ```bash
  chmod 600 .env
  ls -la .env
  # Should show: -rw------- ... .env
  ```

### Security Configuration

- [ ] **Strong Passwords**: All passwords are 16+ characters
  ```bash
  # Generate secure password:
  openssl rand -base64 24
  ```

- [ ] **Unique Passwords**: Database and admin passwords are different

- [ ] **No Defaults**: Changed from example values

- [ ] **.gitignore Updated**: .env file not tracked by git
  ```bash
  echo ".env" >> .gitignore
  ```

### Validation

- [ ] **Syntax Valid**: Docker Compose syntax validated
  ```bash
  docker compose config > /dev/null
  ```

- [ ] **Validation Script Run**: All checks passed
  ```bash
  ./scripts/validate-compose.sh
  ```

## Deployment Steps

### 1. Initial Deployment

- [ ] **Start Services**: Launch MAAS and PostgreSQL
  ```bash
  docker compose up -d
  ```

- [ ] **Check Status**: Verify services are running
  ```bash
  docker compose ps
  # Expected: maas-postgres (Up, healthy), maas-region (Up, healthy)
  ```

- [ ] **Monitor Logs**: Watch startup process
  ```bash
  docker compose logs -f
  # Wait for "MAAS regiond started" message
  ```

### 2. Health Verification

- [ ] **PostgreSQL Healthy**: Database passed health check
  ```bash
  docker inspect maas-postgres --format='{{.State.Health.Status}}'
  # Expected: healthy
  ```

- [ ] **MAAS Healthy**: Region controller passed health check
  ```bash
  docker inspect maas-region --format='{{.State.Health.Status}}'
  # Expected: healthy
  ```

- [ ] **Database Connection**: MAAS connected to PostgreSQL
  ```bash
  docker compose logs maas | grep -i "database\|postgres"
  # No connection errors
  ```

### 3. Web UI Access

- [ ] **UI Accessible**: Web interface loads
  ```
  Open browser: http://<truenas-ip>:5240/MAAS
  ```

- [ ] **Login Successful**: Admin credentials work
  ```
  Username: <from .env>
  Password: <from .env>
  ```

- [ ] **Dashboard Loads**: Main dashboard displays correctly

### 4. Initial Configuration

- [ ] **Boot Images Import Started**: OS images downloading
  ```
  Settings → Images → Select Ubuntu releases → Import
  ```

- [ ] **Import Progress**: Monitor image download
  ```bash
  docker compose logs -f maas | grep -i "image\|download"
  ```

- [ ] **DNS Configuration**: Upstream DNS set
  ```
  Settings → Network Services → DNS → Set forwarders
  ```

- [ ] **Subnet Configuration**: Network subnet defined
  ```
  Subnets → Add subnet or configure existing
  ```

- [ ] **DHCP Enabled**: DHCP configured on subnet (if using PXE)
  ```
  Subnets → <subnet> → Configure DHCP
  ```

## Post-Deployment Verification

### Functional Testing

- [ ] **Image Import Complete**: At least one OS image available
  ```
  Images → Check status shows "Synced"
  ```

- [ ] **API Accessible**: API endpoint responds
  ```bash
  curl -f http://<maas-ip>:5240/MAAS/api/2.0/version/
  ```

- [ ] **Machine Discovery**: Can add machines manually
  ```
  Machines → Add hardware → Machine
  ```

- [ ] **PXE Boot Test**: Physical machine can PXE boot (if applicable)
  ```
  Boot test machine via network
  ```

### Performance Testing

- [ ] **UI Responsive**: Web interface loads in < 2 seconds

- [ ] **API Response Time**: API calls complete in < 500ms
  ```bash
  time curl -f http://<maas-ip>:5240/MAAS/api/2.0/version/
  ```

- [ ] **Resource Usage Acceptable**: Containers using expected resources
  ```bash
  docker stats maas-region maas-postgres
  ```

### Security Verification

- [ ] **Containers Non-Root**: Running as uid/gid 1000
  ```bash
  docker exec maas-region id
  # Expected: uid=1000 gid=1000
  ```

- [ ] **Capabilities Limited**: Only required capabilities present
  ```bash
  docker inspect maas-region | grep -A 10 CapAdd
  # Should show: NET_ADMIN, NET_RAW, NET_BIND_SERVICE
  ```

- [ ] **Network Isolation**: Containers on isolated network (bridge mode)
  ```bash
  docker network ls
  docker network inspect maas-internal
  ```

- [ ] **Secrets Not Exposed**: No passwords in logs
  ```bash
  docker compose logs | grep -i password
  # Should not show actual passwords
  ```

### Persistence Testing

- [ ] **Container Restart**: Data survives restart
  ```bash
  docker compose restart maas
  # Verify UI still accessible, no data loss
  ```

- [ ] **Container Recreate**: Data survives recreation
  ```bash
  docker compose down
  docker compose up -d
  # Verify UI still accessible, configuration preserved
  ```

- [ ] **Database Persistence**: PostgreSQL data preserved
  ```bash
  docker compose restart postgres
  # MAAS reconnects automatically
  ```

## Backup Configuration

- [ ] **Backup Script Ready**: Backup procedure documented
  ```bash
  # See DOCKER-COMPOSE-README.md → Backup and Restore
  ```

- [ ] **Test Backup**: Run initial backup
  ```bash
  ./scripts/backup-maas.sh
  ```

- [ ] **Backup Schedule**: Automated backups configured
  ```bash
  crontab -e
  # Add: 0 2 * * * /path/to/backup-maas.sh
  ```

- [ ] **Backup Verification**: Test restore procedure
  ```bash
  ./scripts/restore-maas.sh <backup-path>
  ```

## Monitoring Setup

- [ ] **Log Rotation**: Logs rotating properly
  ```bash
  docker inspect maas-region | grep -A 5 LogConfig
  # Should show max-size: 10m, max-file: 3
  ```

- [ ] **Health Monitoring**: Health checks passing
  ```bash
  docker compose ps
  # All services show "healthy"
  ```

- [ ] **Resource Monitoring**: Tracking CPU/memory usage
  ```bash
  docker stats maas-region maas-postgres
  ```

- [ ] **Disk Space Monitoring**: Alert on low space
  ```bash
  df -h /mnt/tank/maas/
  ```

## Documentation Review

- [ ] **README.md Read**: Reviewed main documentation

- [ ] **DOCKER-COMPOSE-README.md Read**: Reviewed deployment guide

- [ ] **.env.example Understood**: All variables documented

- [ ] **Troubleshooting Guide Available**: Know where to find help

## Rollback Plan

- [ ] **Backup Created**: Before deployment backup exists

- [ ] **Rollback Documented**: Know how to restore previous state
  ```bash
  docker compose down
  ./scripts/restore-maas.sh <backup-path>
  ```

- [ ] **Emergency Contacts**: Know who to contact for help

## Sign-Off

Deployment completed by: ________________

Date: ________________

Signature: ________________

## Notes

Additional notes or issues encountered during deployment:

```
[Space for notes]
```

## Troubleshooting Reference

### Common Issues and Solutions

**Services won't start:**
```bash
# Check logs
docker compose logs

# Verify permissions
ls -la /mnt/tank/maas/

# Fix ownership
sudo chown -R 1000:1000 /mnt/tank/maas/
```

**Database connection errors:**
```bash
# Check PostgreSQL logs
docker compose logs postgres

# Verify password matches
grep POSTGRES_PASSWORD .env

# Restart services
docker compose restart
```

**UI not accessible:**
```bash
# Check service health
docker compose ps

# Test from host
curl -f http://localhost:5240/MAAS/

# Check firewall
sudo iptables -L -n | grep 5240
```

**PXE boot not working:**
```bash
# Verify host network mode
docker inspect maas-region | grep NetworkMode

# Check capabilities
docker inspect maas-region | grep -A 10 CapAdd

# Test TFTP
tftp <maas-ip>
```

**Out of disk space:**
```bash
# Check usage
du -sh /mnt/tank/maas/*

# Clean old images (via MAAS UI)
# Settings → Images → Delete unused

# Truncate logs
docker compose exec maas truncate -s 0 /var/log/maas/*.log
```

## Support Resources

- **MAAS Documentation**: https://maas.io/docs
- **TrueNAS Forums**: https://forums.truenas.com/
- **GitHub Issues**: https://github.com/yourusername/truenas-maas-app
- **Validation Script**: ./scripts/validate-compose.sh
- **Setup Script**: ./scripts/setup-maas.sh
