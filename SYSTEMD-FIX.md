# Systemd Container Restart Loop - Fix

## Problem

The MAAS container was stuck in a restart loop with the following pattern:
- Entrypoint script runs and completes initialization
- Script says "Handing control to systemd..."
- Container restarts immediately
- Process repeats

## Root Causes

### 1. No Initialization Marker
The entrypoint script was running full initialization on **every container start**, including restarts. There was no way to distinguish between first run and subsequent restarts.

**Impact**: Every restart re-ran database initialization, admin user creation, etc.

### 2. Missing Cgroup Mount
Systemd requires access to `/sys/fs/cgroup` to manage processes and services. Without this mount, systemd fails to start properly in containerized environments.

**Impact**: Systemd likely crashed immediately after the exec, causing container restart.

## Solutions Applied

### Fix 1: Initialization Marker File

**Location**: `docker/entrypoint.sh`

**Changes**:
1. Added marker file check at start of `main()` function
2. If `/var/lib/maas/.initialized` exists, skip all initialization
3. Create marker file after successful initialization
4. Marker persists in the `/var/lib/maas` volume

**Flow**:
```
First Run:
  → No marker file exists
  → Run full initialization
  → Create marker file with timestamp
  → Exec systemd

Subsequent Restarts:
  → Marker file exists
  → Skip initialization completely
  → Exec systemd immediately
```

**Code Added**:
```bash
# At start of main():
local init_marker="/var/lib/maas/.initialized"

if [ -f "$init_marker" ]; then
    log_info "MAAS Already Initialized - Starting systemd"
    log_info "Skipping initialization, handing control to systemd..."
    exec /sbin/init --log-target=console 3>&1
fi

# At end of initialization:
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$init_marker"
chown ${MAAS_UID:-568}:${MAAS_GID:-568} "$init_marker"
```

### Fix 2: Cgroup Mount for Systemd

**Location**: `compose.yaml`

**Changes**:
Added `/sys/fs/cgroup` mount to volumes section:

```yaml
volumes:
  # ... existing volumes ...

  # Systemd cgroup access (required for systemd in container)
  - /sys/fs/cgroup:/sys/fs/cgroup:rw
```

**Why Needed**:
- Systemd requires cgroup access for process management
- Modern systemd (systemd 232+) needs read-write access to cgroups
- Without this, systemd cannot start services or manage processes
- Critical for containerized systemd environments

## Deployment Instructions

### Step 1: Review Changes

```bash
# Check entrypoint changes
git diff docker/entrypoint.sh

# Check compose changes
git diff compose.yaml
```

### Step 2: Rebuild MAAS Image

The entrypoint script changes require rebuilding the Docker image:

```bash
# On TrueNAS (once SSH access is restored)
cd /mnt/pool0/maas/truenas-maas-app
sudo docker compose build maas
```

### Step 3: Clean Start

For a clean deployment, remove old containers and marker:

```bash
# Stop and remove containers
sudo docker compose down

# Optional: Remove old initialization marker if you want fresh init
# (Only do this if you want to re-initialize the database)
# sudo rm -f /mnt/pool0/maas/data/.initialized

# Start with new image
sudo docker compose up -d
```

### Step 4: Monitor Startup

```bash
# Watch logs
sudo docker compose logs -f maas

# First run should show:
# [INFO] MAAS Region Controller Initialization
# ... initialization steps ...
# [INFO] Creating initialization marker at: /var/lib/maas/.initialized
# [INFO] Handing control to systemd...

# On restart (if container restarts), should show:
# [INFO] MAAS Already Initialized - Starting systemd
# [INFO] Skipping initialization, handing control to systemd...
```

### Step 5: Verify Systemd

Once running, check systemd status inside container:

```bash
# Exec into container
sudo docker exec -it maas-region bash

# Check systemd status
systemctl status

# Check MAAS service
systemctl status maas-regiond

# View journal
journalctl -xeu maas-regiond
```

## Expected Behavior

### First Start
1. Entrypoint runs full initialization
2. Database migrations complete
3. Admin user created
4. Marker file created at `/var/lib/maas/.initialized`
5. Systemd takes over as PID 1
6. MAAS services start under systemd management
7. Container stays running

### Container Restart (e.g., after `docker compose restart`)
1. Entrypoint detects marker file
2. Skips all initialization
3. Immediately execs systemd
4. Systemd starts MAAS services
5. Container stays running

### Fresh Install (after removing volumes)
1. No marker file exists
2. Full initialization runs
3. Marker created
4. Proceeds as "First Start" above

## Verification

### Check Marker File
```bash
# On host
sudo ls -la /mnt/pool0/maas/data/.initialized
# Should show: -rw-r--r-- 1 568 568 21 <timestamp> .initialized

# Contents should be ISO timestamp
sudo cat /mnt/pool0/maas/data/.initialized
# Output: 2025-02-12T17:30:45Z (or similar)
```

### Check Container Stability
```bash
# Container should stay running (not restart loop)
sudo docker compose ps
# Status should show "Up" not "Restarting"

# Check restart count
sudo docker inspect maas-region | grep RestartCount
# Should be 0 or very low number
```

### Check MAAS Web UI
```bash
# Should be accessible
curl -I http://172.16.198.12:5240/MAAS/
# Should return HTTP 200 OK
```

## Rollback Plan

If issues occur:

### Rollback Code Changes
```bash
git checkout HEAD~1 docker/entrypoint.sh compose.yaml
sudo docker compose build maas
sudo docker compose up -d
```

### Remove Marker for Re-initialization
```bash
# If marker file is causing issues
sudo rm -f /mnt/pool0/maas/data/.initialized

# Restart to trigger fresh initialization
sudo docker compose restart maas
```

## Notes

- The marker file is stored in `/var/lib/maas` which is mounted as a volume
- This means the marker persists across container recreations
- To force re-initialization, delete the marker file
- Systemd requires SYS_ADMIN capability (already configured in compose.yaml)
- Systemd requires tmpfs mounts for /run, /run/lock, /tmp (already configured)
- Systemd requires seccomp=unconfined (already configured)
- With cgroup mount added, systemd now has all required resources

## Testing Checklist

- [ ] Image builds successfully
- [ ] Container starts without restart loop
- [ ] First run: Full initialization completes
- [ ] Marker file created in `/var/lib/maas/`
- [ ] Systemd takes over successfully
- [ ] MAAS services running under systemd
- [ ] Container restart: Skips initialization
- [ ] Container restart: Systemd starts immediately
- [ ] MAAS web UI accessible
- [ ] Can login with admin credentials
- [ ] Database queries work
- [ ] No permission errors in logs
- [ ] Container stable for 5+ minutes

## Related Files

- `docker/entrypoint.sh` - Initialization script with marker logic
- `compose.yaml` - Docker Compose with cgroup mount
- `Dockerfile` - Systemd configuration (no changes in this fix)

## References

- [Systemd in Docker Containers](https://developers.redhat.com/blog/2016/09/13/running-systemd-in-a-non-privileged-container)
- [Docker Compose cgroup mounting](https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes)
- [Airship MAAS Docker Implementation](https://github.com/airshipit/airship-maas)
