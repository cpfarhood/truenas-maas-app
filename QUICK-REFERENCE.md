# MAAS Docker Compose - Quick Reference Card

## Essential Commands

### Setup & Deployment
```bash
# Interactive setup wizard
./scripts/setup-maas.sh

# Validate configuration
./scripts/validate-compose.sh

# Start services
docker compose up -d

# Monitor startup
docker compose logs -f
```

### Service Management
```bash
# Check service status
docker compose ps

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f maas
docker compose logs -f postgres

# Restart service
docker compose restart maas
docker compose restart postgres

# Stop services
docker compose down

# Stop and remove volumes (DANGER)
docker compose down -v
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
df -h /mnt/tank/
```

### Access Points
```bash
# MAAS Web UI
http://<truenas-ip>:5240/MAAS

# MAAS API
http://<truenas-ip>:5240/MAAS/api/2.0/

# PostgreSQL (from host)
docker compose exec postgres psql -U maas maasdb
```

### Backup & Restore
```bash
# Stop MAAS (keep database running)
docker compose stop maas

# Backup database
docker compose exec -T postgres pg_dump -U maas maasdb | gzip > backup_$(date +%Y%m%d).sql.gz

# Backup volumes
tar -czf volumes_backup_$(date +%Y%m%d).tar.gz /mnt/tank/maas/{config,data,logs}

# Restart MAAS
docker compose start maas

# Restore database
gunzip -c backup_20260212.sql.gz | docker compose exec -T postgres psql -U maas maasdb

# Restore volumes
tar -xzf volumes_backup_20260212.tar.gz -C /
```

### Updates
```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate

# Clean up old images
docker image prune -a
```

### Troubleshooting
```bash
# Check for errors in logs
docker compose logs maas | grep -i error
docker compose logs postgres | grep -i error

# Test database connection
docker compose exec postgres psql -U maas -c "SELECT version();"

# Test MAAS API
curl -f http://localhost:5240/MAAS/api/2.0/version/

# Check container user
docker exec maas-region id

# Fix volume permissions
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/

# Check port availability
netstat -tuln | grep -E '5240|69'

# View network configuration
docker network ls
docker network inspect maas-internal
```

### MAAS Operations (inside container)
```bash
# Enter MAAS container
docker compose exec maas bash

# Login to MAAS CLI
maas login admin http://localhost:5240/MAAS/api/2.0/

# Import boot images
maas admin boot-resources import

# Check import status
maas admin boot-sources read

# List machines
maas admin machines read

# Commission machine
maas admin machine commission <system-id>

# Deploy machine
maas admin machine deploy <system-id> distro_series=jammy
```

## Configuration Files

### Required Files
- `compose.yaml` - Docker Compose configuration
- `.env` - Environment variables (copy from `.env.example`)

### Storage Paths (Default)
- Config: `/mnt/tank/maas/config`
- Data: `/mnt/tank/maas/data`
- Images: `/mnt/tank/maas/images`
- Logs: `/mnt/tank/maas/logs`
- Temp: `/mnt/tank/maas/tmp`
- PostgreSQL: `/mnt/tank/maas/postgres`

### Required Environment Variables
```bash
MAAS_URL=http://192.168.1.100:5240/MAAS
MAAS_ADMIN_PASSWORD=<strong-password>
MAAS_ADMIN_EMAIL=admin@example.com
POSTGRES_PASSWORD=<strong-password>
```

### Optional Environment Variables
```bash
NETWORK_MODE=host              # or bridge
TZ=Etc/UTC                     # or your timezone
MAAS_HTTP_PORT=5240           # only in bridge mode
IMAGE_TAG=3.5                  # MAAS version
```

## Network Configuration

### Host Mode (Recommended)
```bash
# In .env file
NETWORK_MODE=host
```
- Required for PXE boot
- Direct host network access
- No port mapping needed

### Bridge Mode (Testing Only)
```bash
# In .env file
NETWORK_MODE=bridge
MAAS_HTTP_PORT=5240
```
- Isolated network
- No PXE boot capability
- Port mapping required

## Port Reference

| Port | Protocol | Purpose | Network Mode |
|------|----------|---------|--------------|
| 5240 | TCP | HTTP UI/API | Both |
| 5443 | TCP | HTTPS UI/API | Both |
| 69 | UDP | TFTP (PXE) | Host only |
| 8000 | TCP | HTTP Proxy | Both |

## Common Issues

### Services won't start
```bash
# Check logs
docker compose logs

# Verify .env file exists
cat .env

# Check permissions
ls -la /mnt/tank/maas/

# Fix permissions
sudo chown -R 568:568 /mnt/tank/maas/
```

### Database connection error
```bash
# Check PostgreSQL health
docker compose ps postgres

# Verify password matches
grep POSTGRES_PASSWORD .env

# Restart database
docker compose restart postgres
```

### PXE boot not working
```bash
# Verify host network mode
docker inspect maas-region | grep NetworkMode

# Check capabilities
docker inspect maas-region | grep -A 10 CapAdd

# Verify TFTP port
netstat -uln | grep 69
```

### Permission denied
```bash
# Check ownership
ls -la /mnt/tank/maas/

# Fix ownership
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/
```

### Out of disk space
```bash
# Check space
df -h /mnt/tank/

# Check usage by directory
du -sh /mnt/tank/maas/*

# Delete old boot images (via MAAS UI)
# Settings → Images → Delete unused
```

## Security Checklist

- [ ] Changed default passwords
- [ ] Used strong passwords (16+ characters)
- [ ] Set .env file permissions: `chmod 600 .env`
- [ ] Added .env to .gitignore
- [ ] Enabled HTTPS (production)
- [ ] Configured firewall rules
- [ ] Regular backups scheduled
- [ ] Monitoring configured

## Performance Tips

### Storage Optimization
- Use SSD for: config, data, postgres
- Use HDD for: images (large, sequential)

### Database Tuning
```bash
# Add to .env for better performance
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_WORK_MEM=16MB
```

### Resource Limits
```yaml
# Add to compose.yaml under services
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 4G
```

## Maintenance Schedule

### Daily
- Monitor health status: `docker compose ps`
- Check available disk space: `df -h`

### Weekly
- Review logs: `docker compose logs`
- Check for updates: `docker compose pull`
- Monitor resource usage: `docker stats`

### Monthly
- Test backup/restore procedure
- Review security logs
- Update images if available

### Quarterly
- Full security audit
- Performance review
- Documentation updates

## Emergency Procedures

### Complete Restart
```bash
docker compose down
docker compose up -d
docker compose logs -f
```

### Emergency Backup
```bash
docker compose stop maas
docker compose exec -T postgres pg_dump -U maas maasdb > emergency_backup.sql
tar -czf emergency_volumes.tar.gz /mnt/tank/maas/
docker compose start maas
```

### Emergency Restore
```bash
docker compose down
# Restore volumes
tar -xzf emergency_volumes.tar.gz -C /
# Restore database
docker compose up -d postgres
sleep 30
cat emergency_backup.sql | docker compose exec -T postgres psql -U maas maasdb
# Start all services
docker compose up -d
```

### Complete Rebuild
```bash
# Backup first!
docker compose down -v
sudo rm -rf /mnt/tank/maas/*
./scripts/setup-maas.sh
docker compose up -d
```

## Documentation Files

- `compose.yaml` - Docker Compose configuration
- `.env.example` - Environment variable template
- `DOCKER-COMPOSE-README.md` - Full deployment guide
- `DEPLOYMENT-CHECKLIST.md` - Pre/post-deployment checklist
- `COMPOSE-IMPLEMENTATION-SUMMARY.md` - Implementation details
- `QUICK-REFERENCE.md` - This file

## Scripts

- `scripts/validate-compose.sh` - Validate configuration
- `scripts/setup-maas.sh` - Interactive setup wizard

## Support Resources

- **MAAS Docs**: https://maas.io/docs
- **TrueNAS Forums**: https://forums.truenas.com/
- **Docker Compose Docs**: https://docs.docker.com/compose/

## Version Information

- **TrueNAS**: 25.10.0+
- **Docker Compose**: 2.x
- **MAAS**: 3.5
- **PostgreSQL**: 15 Alpine
- **Config Version**: 1.0.0

---

**Quick Help**: Run `./scripts/validate-compose.sh` for diagnostics
