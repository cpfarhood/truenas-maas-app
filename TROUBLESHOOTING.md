# Troubleshooting Guide

## Current Status

### ✅ Working Components
1. **PostgreSQL Database**
   - Running successfully on bridge network (maas-internal)
   - Listening on all interfaces (`listen_addresses = '*'`)
   - Port 5432 exposed to host
   - Health checks passing
   - UID/GID 568 (TrueNAS standard)

2. **Network Connectivity**
   - PostgreSQL accessible from host at `172.16.198.12:5432`
   - MAAS (host network) can reach PostgreSQL (bridge network)
   - Connection test: `pg_isready -h 172.16.198.12 -p 5432 -U maas` succeeds

3. **Configuration**
   - Correct UID/GID 568 throughout
   - Proper directory structure created
   - Environment variables configured
   - Volume paths set correctly

### ❌ Known Issues

#### 1. File Permission Error
```
/usr/local/bin/entrypoint.sh: line 87: /etc/maas/regiond.conf: Permission denied
```

**Cause:** The `/etc/maas` volume is mounted, but the script cannot write configuration files.

**Attempted Fixes:**
- Created `/mnt/pool0/maas/config` with uid/gid 568 ✓
- Mounted as `:rw` in compose.yaml ✓
- Container runs as maas user (uid 568) ✓

**Potential Solutions:**
1. Check actual file permissions inside container: `docker exec maas-region ls -la /etc/maas`
2. Verify volume mount: `docker inspect maas-region | grep -A 10 Mounts`
3. Test write access: `docker exec maas-region touch /etc/maas/test.txt`

#### 2. Sudo Environment Preservation Error ✅ FIXED
```
sudo: sorry, you are not allowed to preserve the environment
```

**Cause:** MAAS initialization requires running `sudo maas-region` commands with environment variables preserved.

**Fix Applied:**
```bash
echo "Defaults:maas !requiretty" > /etc/sudoers.d/maas && \
echo "maas ALL=(ALL) NOPASSWD: SETENV: /usr/sbin/maas-region, /usr/bin/maas" >> /etc/sudoers.d/maas && \
chmod 0440 /etc/sudoers.d/maas
```

**Status:** Fixed in Dockerfile, rebuild required to apply.

## Debugging Commands

### Check Container Status
```bash
cd /mnt/pool0/maas/truenas-maas-app
sudo docker compose ps
sudo docker compose logs maas | tail -50
sudo docker compose logs postgres | tail -50
```

### Test PostgreSQL Connectivity
```bash
# From host
sudo docker exec maas-postgres psql -U maas -d maasdb -c 'SELECT version();'

# From MAAS container
sudo docker exec maas-region pg_isready -h 172.16.198.12 -p 5432 -U maas
```

### Check Permissions
```bash
# Check directory ownership on host
sudo ls -la /mnt/pool0/maas/

# Check permissions inside MAAS container
sudo docker exec maas-region ls -la /etc/maas
sudo docker exec maas-region whoami
sudo docker exec maas-region id
```

### View Volume Mounts
```bash
sudo docker inspect maas-region | grep -A 20 Mounts
```

## Network Architecture

```
┌─────────────────────────────────────┐
│ TrueNAS Host (172.16.198.12)       │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ MAAS Container                │ │
│  │ Network: host                 │ │
│  │ UID/GID: 568 (maas user)      │ │
│  │                               │ │
│  │ Connects to PostgreSQL at:    │ │
│  │ 172.16.198.12:5432           │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Docker Bridge: maas-internal  │ │
│  │ Subnet: 172.20.0.0/16         │ │
│  │                               │ │
│  │  ┌─────────────────────────┐  │ │
│  │  │ PostgreSQL Container    │  │ │
│  │  │ IP: 172.20.0.2          │  │ │
│  │  │ UID/GID: 568           │  │ │
│  │  │ Port: 5432 → 5432      │  │ │
│  │  └─────────────────────────┘  │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

## Environment Variables

Required in `.env`:
```bash
# Database connection (using TrueNAS IP for host→bridge connectivity)
POSTGRES_HOST=172.16.198.12
POSTGRES_PORT=5432
POSTGRES_DB=maasdb
POSTGRES_USER=maas
POSTGRES_PASSWORD=<your-password>

# Storage paths (adjust for your pool)
MAAS_CONFIG_PATH=/mnt/pool0/maas/config
MAAS_DATA_PATH=/mnt/pool0/maas/data
MAAS_IMAGES_PATH=/mnt/pool0/maas/images
MAAS_LOGS_PATH=/mnt/pool0/maas/logs
MAAS_TMP_PATH=/mnt/pool0/maas/tmp
POSTGRES_DATA_PATH=/mnt/pool0/maas/postgres

# MAAS configuration
MAAS_URL=http://172.16.198.12:5240/MAAS
MAAS_ADMIN_USERNAME=admin
MAAS_ADMIN_PASSWORD=<your-admin-password>
MAAS_ADMIN_EMAIL=admin@example.com
```

## Next Steps

1. **Rebuild MAAS Image** ✅ Ready
   - Sudoers configuration fixed with SETENV tag
   - Rebuild command: `docker compose build maas`

2. **Debug File Permissions**
   - Verify `/etc/maas` mount is writable after rebuild
   - Check if SELinux/AppArmor is blocking writes
   - Test: `docker exec maas-region touch /etc/maas/test.txt`

3. **Test Initialization**
   - Once permissions fixed, MAAS should initialize successfully
   - Database migrations will run
   - Admin user will be created
   - MAAS web UI should become accessible at http://172.16.198.12:5240/MAAS

## Configuration Changes Made

### UID/GID: 1000 → 568
- All containers now use TrueNAS standard uid/gid 568
- Dockerfiles updated
- Directory ownership updated

### Network Configuration
- PostgreSQL: bridge network (maas-internal)
- MAAS: host network (required for PXE boot)
- Connection: via exposed port on TrueNAS IP

### PostgreSQL Fixes
- Added `listen_addresses = '*'` to postgresql.conf
- Exposed port 5432:5432
- Custom uid/gid 568 image

### Security Adjustments
- Removed AUDIT_CONTROL and AUDIT_WRITE from cap_drop
- Commented out no-new-privileges for MAAS
- Maintained security for PostgreSQL

## Files Modified

1. `Dockerfile` - MAAS image with uid/gid 568
2. `docker/postgres.Dockerfile` - PostgreSQL with uid/gid 568
3. `docker/postgresql.conf` - Added listen_addresses
4. `compose.yaml` - Network configuration, port mapping
5. `.env` - Database host, storage paths

## Session Summary

This debugging session identified and fixed:
- ✅ UID/GID mismatch (1000 vs 568)
- ✅ Docker user creation conflict
- ✅ PostgreSQL network connectivity
- ✅ PostgreSQL listen configuration
- ✅ Directory structure and ownership
- ✅ Sudo configuration (SETENV tag added)
- ⏳ File write permissions (needs investigation after rebuild)

PostgreSQL is fully operational and accessible. MAAS initialization should succeed after rebuilding with the sudo fix. Only potential remaining issue is file permissions.
