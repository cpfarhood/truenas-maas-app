# Apply Chrony Fix - Quick Guide

## What This Fixes

The `ntp_region` service showing as "Dead" in the MAAS UI, even though chrony is actually running and working correctly.

## Changes Made

Updated `docker/entrypoint.sh` to configure chrony's systemd service with proper Type and PID file settings on every container start.

## Apply the Fix on TrueNAS

### Step 1: Pull the Latest Code

```bash
cd /mnt/pool0/maas/truenas-maas-app
sudo git pull
```

### Step 2: Rebuild the MAAS Image

**IMPORTANT**: Use `--no-cache` to ensure the updated entrypoint.sh is copied into the new image:

```bash
sudo docker compose build --pull --no-cache maas
```

This will take a few minutes as it rebuilds from scratch.

### Step 3: Restart the Container

```bash
sudo docker compose down
sudo docker compose up -d
```

### Step 4: Verify the Fix

Wait 1-2 minutes for full initialization, then check:

```bash
# Check chrony systemd status
sudo docker exec maas-region systemctl status chrony
```

Should show: `Active: active (running)` in green

```bash
# Check MAAS service status
sudo docker exec maas-region maas status
```

Should show all 8 services as "Running":
- ✅ syslog_region
- ✅ proxy
- ✅ temporal-worker
- ✅ bind9
- ✅ temporal
- ✅ regiond
- ✅ reverse_proxy
- ✅ ntp_region ← Should now show "Running" instead of "Dead"

```bash
# Verify chrony is actually working
sudo docker exec maas-region chronyc tracking
```

Should show system time offset, reference ID, stratum, etc.

### Step 5: Check MAAS UI

1. Open: http://172.16.198.12:5240/MAAS/
2. Navigate to: **Controllers** → **Region Controller**
3. All services should now show as "Running"

## If It Doesn't Work

If `ntp_region` still shows as "Dead" after the fix:

### Option A: Manual Fix (Temporary)

```bash
# Create systemd override
sudo docker exec maas-region mkdir -p /etc/systemd/system/chrony.service.d
sudo docker exec maas-region bash -c 'cat > /etc/systemd/system/chrony.service.d/override.conf << EOF
[Service]
Type=forking
PIDFile=/run/chrony/chronyd.pid
Restart=on-failure
RestartSec=5
EOF'

# Reload and restart
sudo docker exec maas-region systemctl daemon-reload
sudo docker exec maas-region systemctl restart chrony
```

### Option B: Try Foreground Mode

```bash
sudo docker exec maas-region bash -c 'cat > /etc/systemd/system/chrony.service.d/override.conf << EOF
[Service]
Type=simple
ExecStart=
ExecStart=/usr/sbin/chronyd -d -f /etc/chrony/chrony.conf
Restart=always
RestartSec=5
EOF'

sudo docker exec maas-region systemctl daemon-reload
sudo docker exec maas-region systemctl restart chrony
```

### Option C: Accept as Cosmetic Issue

If neither option works:
- Chrony **is** running and working correctly
- NTP synchronization is functional
- Only the UI status display is incorrect
- No impact on actual MAAS functionality
- This is a known cosmetic issue with chrony + systemd + Docker

To verify chrony is working despite "Dead" status:
```bash
sudo docker exec maas-region chronyc tracking
sudo docker exec maas-region chronyc sources -v
```

## Troubleshooting

### Check if entrypoint was updated

```bash
# View the entrypoint inside the running container
sudo docker exec maas-region grep -A 10 "Configure chrony" /docker-entrypoint.sh
```

Should show the chrony configuration section. If not, the image wasn't rebuilt properly - use `--no-cache`.

### View chrony logs

```bash
sudo docker exec maas-region journalctl -xeu chrony --no-pager | tail -50
```

### Check PID file

```bash
sudo docker exec maas-region ls -la /run/chrony/
sudo docker exec maas-region cat /run/chrony/chronyd.pid
```

## Expected Results

✅ **After fix**: All 8 services showing as "Running"
✅ **Chrony working**: NTP sync active
✅ **Systemd happy**: Service shows as active (running)
✅ **MAAS UI**: No "Dead" services

## Commit This Fix

Once verified working:

```bash
cd /mnt/pool0/maas/truenas-maas-app
sudo git add docker/entrypoint.sh
sudo git commit -m "Fix chrony systemd service Type for proper status reporting

- Configure chrony to use Type=forking with PID file
- Fixes 'Dead' status in MAAS UI while chrony is running
- Runs on every container start (before init marker check)
- Creates /run/chrony directory with correct permissions

Resolves: ntp_region showing as 'Dead' in MAAS UI"
sudo git push
```

---

*Last Updated: 2026-02-12*
*Fix for chrony "Dead" status in MAAS UI*
