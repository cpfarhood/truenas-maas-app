# TrueNAS MAAS Application - Scripts

This directory contains utility scripts for managing the MAAS application and PostgreSQL database.

## Available Scripts

### PostgreSQL Backup and Restore

#### `backup-postgres.sh`

Creates a logical backup of the PostgreSQL database using `pg_dump`.

**Usage:**
```bash
./scripts/backup-postgres.sh [backup_directory]
```

**Examples:**
```bash
# Backup to default location (/mnt/tank/backups/maas)
./scripts/backup-postgres.sh

# Backup to custom location
./scripts/backup-postgres.sh /path/to/backups
```

**Features:**
- Creates compressed SQL dump (gzip)
- Generates schema-only backup for reference
- Verifies backup integrity
- Automatically cleans up old backups (default: 7 days)
- Generates backup report

**Environment Variables:**
- `BACKUP_RETENTION_DAYS`: Number of days to keep backups (default: 7)
- `POSTGRES_USER`: Database user (default: maas)
- `POSTGRES_DB`: Database name (default: maasdb)

**Output Files:**
- `maasdb-backup-YYYYMMDD-HHMMSS.sql.gz` - Full database backup
- `maasdb-schema-YYYYMMDD-HHMMSS.sql.gz` - Schema-only backup

**Scheduling with Cron:**
```bash
# Add to crontab (daily at 2 AM)
0 2 * * * /path/to/truenas-maas-app/scripts/backup-postgres.sh /mnt/tank/backups/maas
```

---

#### `restore-postgres.sh`

Restores a PostgreSQL database from a backup file.

**Usage:**
```bash
./scripts/restore-postgres.sh <backup_file>
```

**Examples:**
```bash
# Restore from backup
./scripts/restore-postgres.sh /mnt/tank/backups/maas/maasdb-backup-20260212-100000.sql.gz

# List available backups
./scripts/restore-postgres.sh
```

**Features:**
- Verifies backup file integrity before restore
- Creates safety backup of current database
- Stops MAAS service during restore
- Recreates database cleanly
- Verifies successful restore
- Restarts MAAS service
- Generates restore report

**Safety:**
- Requires explicit confirmation (yes/no prompt)
- Creates pre-restore backup in `/tmp`
- Terminates active connections before restore
- Provides rollback instructions

**Important Notes:**
- This operation is destructive - existing data will be replaced
- MAAS service will be stopped during restore (brief downtime)
- Keep the safety backup until you verify the restore is successful

---

## PostgreSQL Management

For comprehensive PostgreSQL documentation, including:
- Non-root user configuration details
- Performance tuning guidelines
- Backup strategies
- Troubleshooting tips
- Monitoring recommendations

See: **[POSTGRESQL-SETUP.md](../POSTGRESQL-SETUP.md)**

## Common Workflows

### Daily Backup Routine

```bash
# Run backup script
./scripts/backup-postgres.sh

# Verify backup was created
ls -lh /mnt/tank/backups/maas/maasdb-backup-*.sql.gz | tail -1

# Test backup integrity
gunzip -t /mnt/tank/backups/maas/maasdb-backup-$(date +%Y%m%d)-*.sql.gz
```

### Disaster Recovery

```bash
# 1. Stop all services
docker compose down

# 2. Restore PostgreSQL volume from snapshot (if available)
sudo zfs rollback tank/maas/postgres@snapshot-name

# 3. OR restore from SQL backup
docker compose up -d postgres
./scripts/restore-postgres.sh /mnt/tank/backups/maas/maasdb-backup-YYYYMMDD-HHMMSS.sql.gz

# 4. Verify data integrity
docker compose logs postgres

# 5. Start all services
docker compose up -d
```

### Database Migration

```bash
# 1. Create backup on source system
./scripts/backup-postgres.sh /tmp/migration

# 2. Copy backup to target system
scp /tmp/migration/maasdb-backup-*.sql.gz target-host:/tmp/

# 3. On target system, restore backup
./scripts/restore-postgres.sh /tmp/maasdb-backup-*.sql.gz

# 4. Verify MAAS configuration
docker compose exec maas-region maas status
```

## Troubleshooting

### Backup Script Issues

**Problem**: "PostgreSQL container is not running"
```bash
# Check container status
docker compose ps

# Start PostgreSQL
docker compose up -d postgres
```

**Problem**: "Backup directory is not writable"
```bash
# Fix permissions
sudo mkdir -p /mnt/tank/backups/maas
sudo chown -R 1000:1000 /mnt/tank/backups/maas
```

**Problem**: "Backup file is corrupted"
```bash
# Test backup integrity
gunzip -t /path/to/backup.sql.gz

# If corrupted, use previous backup
ls -lh /mnt/tank/backups/maas/
```

### Restore Script Issues

**Problem**: "Database restore failed"
```bash
# Check restore log
cat /tmp/restore.log

# Common causes:
# - Backup file corrupted: verify with gunzip -t
# - Database exists with active connections: script handles this
# - Insufficient disk space: check df -h
```

**Problem**: "MAAS won't start after restore"
```bash
# Check MAAS logs
docker compose logs maas

# Common causes:
# - Database schema mismatch: ensure backup is from same MAAS version
# - Configuration issues: verify environment variables
# - Permission issues: check volume ownership (uid/gid 1000)

# Rollback to safety backup
./scripts/restore-postgres.sh /tmp/maasdb-pre-restore-*.sql.gz
```

## Performance Monitoring

### Database Health Check

```bash
# Quick health check
docker exec -t maas-postgres psql -U maas -d maasdb -c "
SELECT
    count(*) as connections,
    current_setting('max_connections')::int as max_connections,
    pg_size_pretty(pg_database_size('maasdb')) as database_size;
"
```

### Backup Size Monitoring

```bash
# Check backup sizes
du -sh /mnt/tank/backups/maas/maasdb-backup-* | tail -10

# Check total backup usage
du -sh /mnt/tank/backups/maas/
```

### Backup Age Verification

```bash
# Find backups older than 7 days
find /mnt/tank/backups/maas -name "maasdb-backup-*.sql.gz" -mtime +7 -ls

# Find most recent backup
ls -lt /mnt/tank/backups/maas/maasdb-backup-*.sql.gz | head -1
```

## Best Practices

1. **Automated Backups**: Schedule daily backups with cron/systemd timer
2. **Backup Verification**: Periodically test restore procedure
3. **Off-site Storage**: Copy backups to remote location or cloud storage
4. **Retention Policy**: Keep 7 daily, 4 weekly, 12 monthly backups
5. **Pre-Change Backups**: Always backup before upgrades or major changes
6. **Monitor Disk Space**: Ensure adequate space for backups and database growth
7. **Document Procedures**: Keep restore procedures accessible during incidents

## Additional Resources

- [PostgreSQL Setup Documentation](../POSTGRESQL-SETUP.md) - Comprehensive PostgreSQL guide
- [Docker Compose README](../DOCKER-COMPOSE-README.md) - Application configuration
- [Deployment Checklist](../DEPLOYMENT-CHECKLIST.md) - Pre-deployment verification
- [Quick Reference](../QUICK-REFERENCE.md) - Common commands and workflows

## Support

For issues or questions:
1. Check [POSTGRESQL-SETUP.md](../POSTGRESQL-SETUP.md) troubleshooting section
2. Review [TrueNAS Community Forums](https://forums.truenas.com/)
3. Check PostgreSQL logs: `docker compose logs postgres`
4. Check MAAS logs: `docker compose logs maas`
