# MAAS Quick Fixes - Common Issues

Quick solutions for common MAAS deployment issues.

## Login Issues

### Problem: "Password doesn't work" or "Invalid credentials"

**Symptoms**:
- Can access UI but login fails
- Created fresh deployment
- Don't remember setting password

**Cause**: Empty or malformed password in `.env` file during initialization

**Quick Fix**:
```bash
# Reset admin password
docker exec maas-region bash -c 'echo -e "newpass123\nnewpass123" | maas-region changepassword admin'

# Login with:
# Username: admin
# Password: newpass123
```

**Proper Fix**:
1. Edit your `.env` file
2. Ensure `MAAS_ADMIN_PASSWORD` is set to a valid password:
   ```bash
   MAAS_ADMIN_PASSWORD=your-secure-password-here
   ```
3. Redeploy for fresh installation

**Prevention**: The latest version validates environment variables at startup and will fail with clear error messages if password is missing.

---

## UI Hangs / Blank Page

### Problem: UI loads header but content area is blank

**Symptoms**:
- MAAS banner/logo appears
- Rest of page is white/blank
- No loading spinner
- Browser console may show errors

**Cause**: Missing runtime directories or service initialization issues

**Quick Fixes**:

1. **Check missing directories**:
```bash
docker exec maas-region bash -c '
mkdir -p /var/lib/maas/prometheus \
         /var/lib/maas/certificates \
         /var/lib/maas/http \
         /var/lib/maas/image-storage/bootloaders
chown -R 568:568 /var/lib/maas
'
```

2. **Restart region controller**:
```bash
docker exec maas-region systemctl restart maas-regiond
sleep 10
```

3. **Check webapp sockets exist**:
```bash
docker exec maas-region ls -la /var/lib/maas/ | grep sock
```

Should see:
```
srw-rw-rw- 1 maas maas 0 ... apiserver-http.sock
srw-rw-rw- 1 maas maas 0 ... maas-regiond-webapp.sock.0
srw-rw-rw- 1 maas maas 0 ... maas-regiond-webapp.sock.1
srw-rw-rw- 1 maas maas 0 ... maas-regiond-webapp.sock.2
srw-rw-rw- 1 maas maas 0 ... maas-regiond-webapp.sock.3
```

4. **If sockets missing, check logs**:
```bash
docker exec maas-region journalctl -xeu maas-regiond --no-pager | tail -100
```

5. **Verify API is responding**:
```bash
curl http://localhost:5240/MAAS/api/2.0/version/
```

Should return JSON with version info.

**Prevention**: Latest Dockerfile creates all required directories at build time.

---

## Container Restart Loop

### Problem: Container keeps restarting

**Symptoms**:
- `docker compose ps` shows "Restarting"
- Logs show same initialization messages repeatedly
- Container uptime is very low

**Cause**: Systemd not starting properly or entrypoint exiting

**Quick Fix**:

1. **Check for initialization marker**:
```bash
docker exec maas-region ls -la /var/lib/maas/.initialized
```

If missing, systemd might not be taking over properly.

2. **Check systemd status**:
```bash
docker exec maas-region systemctl status
```

3. **Verify cgroup mount**:
```bash
docker inspect maas-region | grep cgroup
```

Should show: `/sys/fs/cgroup:/sys/fs/cgroup:rw`

4. **Check for missing mounts**:
```bash
docker exec maas-region mount | grep -E 'tmpfs|cgroup'
```

Should see tmpfs on `/run`, `/run/lock`, `/tmp` and cgroup on `/sys/fs/cgroup`

**Prevention**: Fixed in latest version with:
- Initialization marker file
- Proper systemd configuration
- Required mounts in compose.yaml

---

## Service Won't Start

### Problem: MAAS HTTP service or other services fail to start

**Symptoms**:
- `systemctl status maas-http` shows "inactive (dead)"
- Nginx config errors in logs
- "ConditionPathExists" failures

**Quick Fixes**:

1. **For maas-http nginx config issue**:
```bash
# Check if regiond.nginx.conf exists
docker exec maas-region ls -la /var/lib/maas/http/

# If regiond.nginx.conf exists but nginx.conf doesn't:
docker exec maas-region /usr/local/bin/setup-nginx-config.sh

# Then start the service
docker exec maas-region systemctl start maas-http
```

2. **For general service failures**:
```bash
# Check service status
docker exec maas-region systemctl status maas-regiond
docker exec maas-region systemctl status maas-apiserver
docker exec maas-region systemctl status maas-http

# Check dependencies
docker exec maas-region systemctl list-dependencies maas-http
```

3. **View detailed error logs**:
```bash
docker exec maas-region journalctl -xeu maas-http --no-pager
```

**Prevention**: Latest version includes systemd service chain for automatic nginx config generation.

---

## Database Connection Errors

### Problem: Can't connect to PostgreSQL

**Symptoms**:
- "Failed to connect to PostgreSQL" in logs
- Initialization hangs at "Waiting for PostgreSQL"
- Connection refused errors

**Quick Fixes**:

1. **Check PostgreSQL is running**:
```bash
docker compose ps postgres
```

Should show "Up" and "(healthy)"

2. **Test connection from MAAS container**:
```bash
docker exec maas-region pg_isready -h localhost -p 5432 -U maas
```

3. **Check POSTGRES_HOST in .env**:
```bash
# For host network mode (default):
POSTGRES_HOST=localhost

# Or use your TrueNAS IP:
POSTGRES_HOST=192.168.1.100
```

4. **Verify PostgreSQL is listening**:
```bash
docker exec maas-postgres psql -U maas -d maasdb -c "SELECT version();"
```

**Prevention**: Ensure `.env` file has correct `POSTGRES_HOST` for your network mode.

---

## Permission Denied Errors

### Problem: Permission denied on files/directories

**Symptoms**:
- "Permission denied" errors in logs
- Can't create files in volumes
- Services fail to start with permission errors

**Quick Fix**:
```bash
# On TrueNAS host, fix ownership
sudo chown -R 568:568 /mnt/pool0/maas/
sudo chmod -R 755 /mnt/pool0/maas/

# Restart containers
docker compose restart
```

**Check Ownership**:
```bash
ls -la /mnt/pool0/maas/
# Should show: drwxr-xr-x ... 568 568
```

**Prevention**: All containers run as uid/gid 568. Ensure volume paths are owned by 568:568.

---

## Health Check Failing

### Problem: Container shows as "unhealthy"

**Symptoms**:
- `docker compose ps` shows "(unhealthy)"
- Container is running but marked unhealthy
- Health check command fails

**Quick Fixes**:

1. **Check what the health check is testing**:
```bash
docker inspect maas-region | grep -A 5 Healthcheck
```

2. **Test health check manually**:
```bash
docker exec maas-region curl -f -I http://localhost:5240/MAAS/
```

Should return HTTP 301 or 200.

3. **Give more time for startup**:
Health check has 120s start period. Wait 2-3 minutes after container start.

4. **Check if services are running**:
```bash
docker exec maas-region systemctl status maas-http
docker exec maas-region systemctl status maas-regiond
```

**Prevention**: Latest version uses reliable UI endpoint for health checks instead of API.

---

## Missing Boot Images

### Problem: No OS images available for deployment

**Symptoms**:
- Empty images list in UI
- "No boot images" warning
- Can't deploy machines

**Fix**:
1. Login to MAAS UI
2. Go to **Settings** → **Images**
3. Select Ubuntu releases you want (e.g., 22.04, 24.04)
4. Click **Import** or **Sync**
5. Wait 30-60 minutes for download

**Auto-import**:
Set in `.env`:
```bash
MAAS_BOOT_IMAGES_AUTO_IMPORT=true
```

This starts automatic import on first run (but still takes time).

---

## Check Overall System Status

**Quick Health Check**:
```bash
# Container status
docker compose ps

# Service status
docker exec maas-region systemctl status maas-regiond
docker exec maas-region systemctl status maas-http

# API check
curl http://localhost:5240/MAAS/api/2.0/version/

# Database check
docker exec maas-postgres psql -U maas -d maasdb -c "SELECT COUNT(*) FROM maasserver_node;"

# Logs
docker compose logs maas | tail -50
```

**Reset Everything** (destructive - loses data):
```bash
docker compose down
sudo rm -rf /mnt/pool0/maas/data/.initialized
sudo rm -rf /mnt/pool0/maas/postgres/*
docker compose up -d
```

---

## Get Help

### Debugging Commands
```bash
# Full service status
docker exec maas-region systemctl list-units 'maas-*'

# All logs
docker compose logs --tail 200

# Inside container
docker exec -it maas-region bash
```

### Documentation
- Main README: `README.md`
- Deployment Status: `DEPLOYMENT-STATUS.md`
- Systemd Fix: `SYSTEMD-FIX.md`
- Troubleshooting: `TROUBLESHOOTING.md`

### Support
- GitHub Issues: https://github.com/cpfarhood/truenas-maas-app/issues
- MAAS Docs: https://maas.io/docs
- TrueNAS Forums: https://www.truenas.com/community/

---

*Last Updated: 2026-02-12*
*Covers common issues found during deployment and testing*
