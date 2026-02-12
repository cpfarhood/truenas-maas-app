# Chrony (NTP Region) Service "Dead" Status Fix

## Problem

The `ntp_region` service (chrony) shows as "Dead" in the MAAS UI, but chrony is actually running and functioning properly. This is a systemd readiness signal issue.

## Investigation Commands

Run these commands on your TrueNAS server to diagnose the issue:

```bash
# Check chrony systemd service status
docker exec maas-region systemctl status chrony

# View chrony service configuration
docker exec maas-region systemctl cat chrony

# Check chrony logs
docker exec maas-region journalctl -xeu chrony --no-pager | tail -50

# Verify chrony is actually running
docker exec maas-region ps aux | grep chrony

# Check NTP sync status
docker exec maas-region chronyc tracking
```

## Root Cause

Chrony's systemd service is likely configured as `Type=forking` but chrony might not be signaling completion properly, or it's configured as `Type=simple` and exits immediately after forking.

Common issues:
1. **Type=forking**: Systemd expects a PID file that doesn't get created
2. **Type=simple**: Process daemonizes and parent exits, systemd thinks it died
3. **No notify mechanism**: Chrony doesn't signal readiness to systemd

## Solution Options

### Option 1: Fix Systemd Service Type (Recommended)

Modify the chrony systemd service to use the correct Type setting:

```bash
# Create systemd override directory
docker exec maas-region mkdir -p /etc/systemd/system/chrony.service.d

# Create override configuration
docker exec maas-region bash -c 'cat > /etc/systemd/system/chrony.service.d/override.conf << EOF
[Service]
Type=forking
PIDFile=/run/chrony/chronyd.pid
Restart=on-failure
RestartSec=5
EOF'

# Reload systemd configuration
docker exec maas-region systemctl daemon-reload

# Restart chrony
docker exec maas-region systemctl restart chrony

# Verify status
docker exec maas-region systemctl status chrony
```

### Option 2: Add to Entrypoint Script (Persistent)

To make this fix persistent across container restarts, add it to the entrypoint script:

**File**: `docker/entrypoint.sh`

Add after the bind9 configuration (around line 218):

```bash
# Configure chrony systemd service for proper status reporting
log_info "Configuring chrony systemd service..."
mkdir -p /etc/systemd/system/chrony.service.d
cat > /etc/systemd/system/chrony.service.d/override.conf << 'EOF'
[Service]
Type=forking
PIDFile=/run/chrony/chronyd.pid
Restart=on-failure
RestartSec=5
EOF

# Ensure PID directory exists with correct permissions
mkdir -p /run/chrony
chown ${MAAS_UID:-568}:${MAAS_GID:-568} /run/chrony
```

Then rebuild and restart:

```bash
sudo docker compose build --no-cache maas
sudo docker compose down
sudo docker compose up -d
```

### Option 3: Alternative systemd Configuration

If Option 1 doesn't work, try this alternative configuration:

```bash
docker exec maas-region bash -c 'cat > /etc/systemd/system/chrony.service.d/override.conf << EOF
[Service]
Type=simple
ExecStart=
ExecStart=/usr/sbin/chronyd -d -f /etc/chrony/chrony.conf
Restart=always
RestartSec=5
EOF'

docker exec maas-region systemctl daemon-reload
docker exec maas-region systemctl restart chrony
```

This runs chrony in foreground mode (`-d`) which is better for systemd `Type=simple`.

## Verification

After applying the fix:

1. **Check systemd status**:
   ```bash
   docker exec maas-region systemctl status chrony
   ```
   Should show `Active: active (running)` in green

2. **Check MAAS UI**:
   - Navigate to Controllers → Region Controller
   - `ntp_region` should show as "Running" instead of "Dead"

3. **Verify NTP functionality**:
   ```bash
   docker exec maas-region chronyc sources
   docker exec maas-region chronyc tracking
   ```
   Should show active NTP sources and synchronization status

## Why This Happens

1. **Chrony daemonizes by default**: It forks into background and parent process exits
2. **Systemd expects different behavior**: Depending on `Type=`, systemd expects:
   - `Type=simple`: Process stays in foreground
   - `Type=forking`: Process forks, creates PID file
   - `Type=notify`: Process sends readiness signal via sd_notify()
3. **Mismatch causes "Dead" status**: If Type doesn't match actual behavior, systemd thinks process died

## Impact

- **Functional Impact**: NONE - chrony is actually running and providing NTP services
- **Cosmetic Impact**: UI shows service as "Dead" which is misleading
- **Monitoring Impact**: May trigger false alerts in monitoring systems

## Alternative: Accept as Cosmetic Issue

If the fix doesn't work or causes issues, this can be accepted as a cosmetic problem:
- Chrony is running and functional
- NTP synchronization works correctly
- Only the UI status display is incorrect
- No impact on MAAS functionality

To verify chrony is working despite "Dead" status:
```bash
docker exec maas-region chronyc tracking
# Should show: Reference ID, Stratum, System time, etc.
```

## References

- [systemd.service man page](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Chrony documentation](https://chrony.tuxfamily.org/documentation.html)
- [systemd Type= directive explained](https://www.freedesktop.org/software/systemd/man/systemd.service.html#Type=)

---

*Last Updated: 2026-02-12*
*Issue: chrony running but showing as "Dead" in MAAS UI*
