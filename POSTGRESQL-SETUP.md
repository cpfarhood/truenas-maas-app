# PostgreSQL Setup for TrueNAS MAAS Application

## Table of Contents

1. [Overview](#overview)
2. [The Non-Root User Challenge](#the-non-root-user-challenge)
3. [Solution Architecture](#solution-architecture)
4. [Custom PostgreSQL Image](#custom-postgresql-image)
5. [Configuration Files](#configuration-files)
6. [Performance Tuning](#performance-tuning)
7. [Backup and Restore](#backup-and-restore)
8. [Troubleshooting](#troubleshooting)
9. [Monitoring](#monitoring)
10. [References](#references)

---

## Overview

This document describes the PostgreSQL setup for the TrueNAS MAAS application, specifically addressing the challenges of running PostgreSQL with TrueNAS 25.10+ requirements while maintaining proper database functionality and security.

### Key Features

- **TrueNAS-Compatible**: Runs with uid/gid 568 as required by TrueNAS 25.10+
- **Production-Ready**: Optimized configuration for MAAS workloads
- **Automated Initialization**: Database and extensions configured automatically
- **Performance Tuned**: Settings optimized for MAAS region controller operations
- **Backup-Friendly**: Volume layout supports both logical and physical backups

---

## The Non-Root User Challenge

### The Problem

TrueNAS 25.10+ requires all application containers to run as non-root users with uid/gid 568. However, PostgreSQL's official Docker images are designed to run as:

- **postgres user** with uid 999 (on Debian-based images)
- **postgres user** with uid 70 (on Alpine-based images)

Running the official PostgreSQL image with `user: "568:568"` causes several issues:

1. **Permission Errors**: `chmod: /var/lib/postgresql/data: Operation not permitted`
2. **Initialization Failures**: Database cluster cannot be initialized
3. **Runtime Errors**: PostgreSQL cannot access its data directory
4. **Socket Errors**: Unix domain sockets cannot be created in `/var/run/postgresql`

### Why This Happens

PostgreSQL's entrypoint script (`docker-entrypoint.sh`) attempts to:

1. Change ownership of data directories to the postgres user (uid 70 or 999)
2. Set directory permissions to 700 (required for PostgreSQL security)
3. Create Unix domain sockets with postgres user ownership

When Docker runs the container with `user: "568:568"`, the container process:

- Cannot change ownership from uid 568 to uid 70/999
- Conflicts with host filesystem ownership expectations
- Fails security checks for data directory permissions

### TrueNAS Community Solutions

Research on TrueNAS forums reveals several approaches:

1. **Named Volumes**: Avoid bind mounts, use Docker-managed volumes
2. **Init Containers**: Use busybox to pre-configure permissions as root
3. **Custom Images**: Rebuild PostgreSQL with uid/gid 568
4. **ACL Permissions**: Set TrueNAS ACLs to match PostgreSQL expectations

For this project, we've chosen a **custom image approach** as it provides:

- Clean integration with Docker Compose
- No runtime permission fixing overhead
- Proper PostgreSQL security model
- Compatibility with both bind mounts and named volumes

---

## Solution Architecture

### Custom PostgreSQL Image

We build a custom PostgreSQL image that:

1. **Removes** the default postgres user (uid 70/999)
2. **Creates** a new postgres user with uid/gid 568
3. **Reconfigures** PostgreSQL to work with the new user
4. **Includes** MAAS-specific initialization scripts
5. **Provides** optimized configuration for MAAS workloads

### Directory Structure

```
/Users/cpfarhood/Documents/Repositories/truenas-maas-app/
├── docker/
│   ├── postgres.Dockerfile          # Custom PostgreSQL image definition
│   ├── postgres-entrypoint.sh       # Custom entrypoint wrapper
│   ├── postgres-init.sh             # MAAS database initialization
│   └── postgresql.conf              # Performance-tuned configuration
└── compose.yaml                     # Docker Compose with custom build
```

### Build Process

```yaml
# In compose.yaml
postgres:
  build:
    context: .
    dockerfile: docker/postgres.Dockerfile
    args:
      POSTGRES_UID: 1000
      POSTGRES_GID: 1000
  user: "568:568"
```

---

## Custom PostgreSQL Image

### Dockerfile Overview (`docker/postgres.Dockerfile`)

The custom Dockerfile performs these key operations:

#### 1. Base Image Selection

```dockerfile
FROM postgres:15-alpine
```

We use the Alpine variant for:
- Smaller image size (~80MB vs ~300MB for Debian)
- Faster builds and deployments
- Lower security surface area

#### 2. User Reconfiguration

```dockerfile
# Remove default postgres user (uid 70 in alpine)
RUN deluser postgres 2>/dev/null || true && \
    delgroup postgres 2>/dev/null || true

# Create postgres user with TrueNAS-compatible uid/gid (1000)
RUN addgroup -g 1000 postgres && \
    adduser -D -u 1000 -G postgres -h /var/lib/postgresql -s /bin/bash postgres
```

This ensures the postgres user inside the container matches the uid/gid 568 requirement.

#### 3. Directory Preparation

```dockerfile
# Create necessary directories with proper ownership
RUN mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 2777 /var/run/postgresql

RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chmod 700 /var/lib/postgresql/data
```

#### 4. Custom Scripts Integration

```dockerfile
# Copy MAAS initialization script
COPY --chown=postgres:postgres docker/postgres-init.sh /docker-entrypoint-initdb.d/01-maas-init.sh

# Copy performance configuration
COPY --chown=postgres:postgres docker/postgresql.conf /etc/postgresql/postgresql.conf

# Copy custom entrypoint wrapper
COPY --chown=postgres:postgres docker/postgres-entrypoint.sh /usr/local/bin/postgres-entrypoint.sh
```

---

## Configuration Files

### 1. postgres-entrypoint.sh

**Purpose**: Wrapper around official PostgreSQL entrypoint that ensures proper permissions.

**Key Functions**:

- Validates running user is uid 568
- Fixes permissions on PGDATA and runtime directories
- Checks for existing data to prevent corruption
- Logs initialization progress
- Transfers control to official PostgreSQL entrypoint

**Permission Handling Logic**:

```bash
# Only fix ownership if:
# 1. Directory is empty (new installation), OR
# 2. Already owned by uid 568, OR
# 3. Owned by uid 999 (conversion from official image)
if [ -z "$(ls -A "$target_dir")" ] || \
   [ "$current_owner" = "568:568" ] || \
   [ "$current_owner" = "999:999" ]; then
    chown -R 568:568 "$target_dir"
fi
```

This prevents data corruption if existing data has unexpected ownership.

### 2. postgres-init.sh

**Purpose**: Initializes the MAAS database with required extensions and settings.

**Operations**:

1. **Wait for PostgreSQL**: Ensures database is ready before configuration
2. **Create Extensions**:
   ```sql
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- UUID generation
   CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- Trigram matching for search
   ```
3. **Grant Privileges**: Ensures MAAS user has full database access
4. **Performance Tuning**:
   ```sql
   ALTER DATABASE maasdb SET synchronous_commit = 'off';  -- Faster writes
   ALTER DATABASE maasdb SET full_page_writes = 'on';     -- Crash safety
   ```
5. **Marker File**: Creates `.maas-initialized` to track initialization

**Execution**: Runs automatically during first database initialization via PostgreSQL's init mechanism (`/docker-entrypoint-initdb.d/`).

### 3. postgresql.conf

**Purpose**: Performance-tuned PostgreSQL configuration optimized for MAAS workloads.

See [Performance Tuning](#performance-tuning) section for detailed parameter descriptions.

---

## Performance Tuning

### Memory Configuration

The most critical parameters for PostgreSQL performance:

#### shared_buffers

**What it does**: RAM dedicated to caching database pages.

**Recommended value**: 25% of total system RAM

**Why**: PostgreSQL loads frequently accessed data into shared buffers. More memory = fewer disk reads.

**Examples**:
- 8GB RAM system: `shared_buffers = 2GB`
- 16GB RAM system: `shared_buffers = 4GB`
- 32GB+ RAM system: `shared_buffers = 8GB`

**In postgresql.conf**:
```
shared_buffers = 2GB  # Adjust based on your RAM
```

#### effective_cache_size

**What it does**: Tells PostgreSQL how much memory is available for caching (including OS cache).

**Recommended value**: 50-75% of total system RAM

**Why**: Influences query planner decisions. Higher values favor index scans.

**Examples**:
- 8GB RAM system: `effective_cache_size = 6GB`
- 16GB RAM system: `effective_cache_size = 12GB`
- 32GB+ RAM system: `effective_cache_size = 24GB`

**In postgresql.conf**:
```
effective_cache_size = 6GB  # Adjust based on your RAM
```

#### work_mem

**What it does**: RAM per operation for sorts, joins, and hash tables.

**Recommended value**: `shared_buffers / max_connections`, minimum 4MB

**Why**: Complex queries need memory for sorting and joining data.

**Calculation**:
```
work_mem = shared_buffers / max_connections
Example: 2GB / 100 connections = 20MB
```

**In postgresql.conf**:
```
work_mem = 20MB
```

**Warning**: Each query can use work_mem multiple times (for each sort/join operation). Set conservatively.

#### maintenance_work_mem

**What it does**: RAM for maintenance operations (VACUUM, CREATE INDEX, etc.).

**Recommended value**: 5-10% of total system RAM, maximum 2GB per operation

**Why**: Faster index creation and table maintenance.

**In postgresql.conf**:
```
maintenance_work_mem = 512MB
```

### Storage Configuration

#### random_page_cost

**What it does**: Cost estimate for random disk access vs. sequential.

**Recommended values**:
- SSD/NVMe: `1.1`
- HDD: `4.0` (default)

**Why**: Lower values favor index scans when using fast storage.

**In postgresql.conf**:
```
random_page_cost = 1.1  # For SSD storage
```

#### effective_io_concurrency

**What it does**: Number of concurrent disk I/O operations.

**Recommended values**:
- NVMe SSD: `200`
- SATA SSD: `50`
- HDD RAID: `10`

**Why**: Tells PostgreSQL how many I/O operations can run simultaneously.

**In postgresql.conf**:
```
effective_io_concurrency = 200  # For NVMe
```

### Write-Ahead Log (WAL) Tuning

#### wal_buffers

**What it does**: RAM buffer for WAL (transaction log) writes.

**Recommended value**: `16MB` for most systems

**Why**: Reduces disk writes by batching WAL data.

**In postgresql.conf**:
```
wal_buffers = 16MB
```

#### min_wal_size and max_wal_size

**What they do**: Control WAL file retention and checkpoint frequency.

**Recommended values**:
```
min_wal_size = 1GB   # Keep at least 1GB of WAL
max_wal_size = 4GB   # Checkpoint if WAL exceeds 4GB
```

**Why**: Prevents excessive checkpointing while limiting disk usage.

#### checkpoint_completion_target

**What it does**: Spreads checkpoint I/O over this fraction of checkpoint interval.

**Recommended value**: `0.9`

**Why**: Smooth I/O distribution instead of I/O spikes.

**In postgresql.conf**:
```
checkpoint_completion_target = 0.9
```

### Connection Management

#### max_connections

**What it does**: Maximum concurrent database connections.

**Recommended for MAAS**:
- Small deployment (< 100 nodes): `50`
- Medium deployment (100-500 nodes): `100`
- Large deployment (500+ nodes): `200`

**Why**: Each connection consumes memory (~10MB). Too many = OOM.

**In postgresql.conf**:
```
max_connections = 100
```

**Note**: If you need more connections, use PgBouncer connection pooler.

### Autovacuum Tuning

**What it does**: Automatic maintenance to reclaim space and update statistics.

**Critical for MAAS**: MAAS does many INSERT/UPDATE/DELETE operations. Without autovacuum, tables bloat and performance degrades.

**Key parameters**:
```
autovacuum = on                           # Enable (critical!)
autovacuum_max_workers = 3                # Parallel vacuum processes
autovacuum_naptime = 1min                 # Check interval
autovacuum_vacuum_scale_factor = 0.1      # Vacuum at 10% dead tuples
autovacuum_analyze_scale_factor = 0.05    # Analyze at 5% changes
```

### Logging for Performance Analysis

**What to log**:
```
log_min_duration_statement = 1000   # Log queries > 1 second
log_checkpoints = on                # Log checkpoint activity
log_lock_waits = on                 # Log lock contention
log_temp_files = 0                  # Log temp file usage (I/O pressure)
log_autovacuum_min_duration = 0     # Log all autovacuum activity
```

**Why**: Identifies slow queries and performance bottlenecks.

### MAAS-Specific Optimizations

**Database-level settings** (applied in postgres-init.sh):

```sql
ALTER DATABASE maasdb SET synchronous_commit = 'off';
```

**What it does**: Allows PostgreSQL to return "success" before WAL is flushed to disk.

**Why**: MAAS can tolerate losing a few milliseconds of data in exchange for 2-3x faster writes.

**Risk**: Very small chance of data loss if server crashes within ~few milliseconds of transaction commit.

**Acceptable for MAAS**: Node state data can be re-synchronized. Not suitable for financial transactions.

---

## Backup and Restore

### Backup Strategy

A comprehensive backup strategy uses multiple approaches:

#### 1. Logical Backups (pg_dump/pg_dumpall)

**Advantages**:
- Human-readable SQL
- Portable across PostgreSQL versions
- Selective restore (specific tables/databases)
- Compressed backups

**Disadvantages**:
- Slower than physical backups
- Larger backup size
- Requires database to be running for restore

**Commands**:

**Full database backup**:
```bash
docker exec -t maas-postgres pg_dump -U maas -d maasdb | gzip > maasdb-backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

**All databases and roles**:
```bash
docker exec -t maas-postgres pg_dumpall -U maas | gzip > postgres-full-backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

**Schema only**:
```bash
docker exec -t maas-postgres pg_dump -U maas -d maasdb --schema-only | gzip > maasdb-schema-$(date +%Y%m%d-%H%M%S).sql.gz
```

**Restore**:
```bash
# Stop MAAS to prevent conflicts
docker compose stop maas

# Restore database
gunzip -c maasdb-backup-20260212-100000.sql.gz | docker exec -i maas-postgres psql -U maas -d maasdb

# Restart MAAS
docker compose start maas
```

#### 2. Physical Backups (Volume Copy)

**Advantages**:
- Fastest backup method
- Exact replica of data directory
- Includes all databases and configuration

**Disadvantages**:
- Must stop PostgreSQL first (or use pg_basebackup)
- Not portable across PostgreSQL versions
- Larger size (includes indexes)

**Commands**:

**Stop-based backup**:
```bash
# Stop services
docker compose stop

# Backup volume
sudo tar -czf postgres-volume-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
    /mnt/tank/maas/postgres

# Restart services
docker compose start
```

**Hot backup with pg_basebackup**:
```bash
# Create backup directory
mkdir -p /mnt/tank/backups/postgres

# Hot backup (no downtime)
docker exec -t maas-postgres pg_basebackup \
    -U maas -D /var/lib/postgresql/backup \
    -Ft -z -P

# Copy from container
docker cp maas-postgres:/var/lib/postgresql/backup \
    /mnt/tank/backups/postgres/backup-$(date +%Y%m%d-%H%M%S)
```

**Restore**:
```bash
# Stop services
docker compose stop

# Remove old data
sudo rm -rf /mnt/tank/maas/postgres/*

# Restore backup
sudo tar -xzf postgres-volume-backup-20260212-100000.tar.gz -C /

# Fix permissions
sudo chown -R 568:568 /mnt/tank/maas/postgres

# Restart services
docker compose start
```

#### 3. Continuous Archiving (WAL Archiving)

**For advanced users**: Set up WAL archiving for point-in-time recovery (PITR).

**Configuration**:
```
# In postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /mnt/tank/maas/postgres-wal-archive/%f'
```

**Benefits**: Restore to any point in time between backups.

**Complexity**: Requires additional setup and monitoring.

### Backup Schedule Recommendations

**Production Systems**:
- **Daily**: Logical backup (pg_dump) at 2 AM
- **Weekly**: Physical backup (volume copy) on Sunday
- **Monthly**: Full backup verification with restore test

**Development Systems**:
- **Weekly**: Logical backup before major changes
- **Before upgrades**: Full volume backup

### Backup Retention

**Recommended retention**:
- Daily backups: Keep last 7 days
- Weekly backups: Keep last 4 weeks
- Monthly backups: Keep last 12 months

**Automation with cron**:
```bash
# Add to TrueNAS cron or systemd timer
0 2 * * * /path/to/backup-script.sh
```

### Backup Verification

**Always test your backups!**

**Quarterly verification**:
1. Restore backup to test environment
2. Verify data integrity
3. Test application functionality
4. Document restore time

### Off-Site Backups

**Critical for disaster recovery**:

- **Cloud Storage**: S3, Backblaze B2, Google Cloud Storage
- **Remote TrueNAS**: Replication to another TrueNAS system
- **Remote Location**: Physical drive stored off-site

**Example S3 backup**:
```bash
# Upload backup to S3
aws s3 cp maasdb-backup-$(date +%Y%m%d).sql.gz \
    s3://my-backup-bucket/maas/$(date +%Y%m%d)/
```

---

## Troubleshooting

### Permission Issues

**Symptom**: `chmod: /var/lib/postgresql/data: Operation not permitted`

**Cause**: Data directory not owned by uid 568

**Solution**:
```bash
# On TrueNAS host
sudo chown -R 568:568 /mnt/tank/maas/postgres
sudo chmod -R 700 /mnt/tank/maas/postgres
```

### Database Won't Start

**Symptom**: Container exits immediately with error

**Diagnosis**:
```bash
# Check logs
docker compose logs postgres

# Common errors:
# - "data directory has wrong ownership"
# - "FATAL: data directory has wrong permissions"
# - "initdb: could not create directory"
```

**Solution**:
```bash
# Verify directory exists
ls -la /mnt/tank/maas/postgres

# Fix ownership and permissions
sudo chown -R 568:568 /mnt/tank/maas/postgres
sudo chmod 700 /mnt/tank/maas/postgres

# Restart
docker compose restart postgres
```

### Connection Refused

**Symptom**: MAAS cannot connect to PostgreSQL

**Diagnosis**:
```bash
# Check if PostgreSQL is running
docker compose ps postgres

# Check if port is accessible
docker exec maas-postgres pg_isready -U maas

# Check network connectivity
docker exec maas-region nc -zv postgres 5432
```

**Solutions**:

1. **PostgreSQL not ready**: Wait for healthcheck to pass
   ```bash
   docker compose ps  # Look for "healthy" status
   ```

2. **Wrong password**: Verify environment variables match
   ```bash
   docker compose config | grep POSTGRES_PASSWORD
   ```

3. **Network issues**: Verify both containers on same network
   ```bash
   docker network inspect maas-internal
   ```

### Slow Performance

**Symptom**: Queries taking longer than expected

**Diagnosis**:

1. **Check slow query log**:
   ```bash
   docker exec -t maas-postgres tail -f /var/lib/postgresql/data/log/postgresql-*.log | grep "duration:"
   ```

2. **Check current connections**:
   ```bash
   docker exec -t maas-postgres psql -U maas -d maasdb -c "SELECT count(*) FROM pg_stat_activity;"
   ```

3. **Check for locks**:
   ```bash
   docker exec -t maas-postgres psql -U maas -d maasdb -c "SELECT * FROM pg_locks WHERE NOT granted;"
   ```

**Solutions**:

1. **Too many connections**: Reduce max_connections or add connection pooler
2. **Memory pressure**: Increase shared_buffers and effective_cache_size
3. **Disk I/O**: Check TrueNAS pool performance, consider faster storage
4. **Bloated tables**: Run VACUUM FULL (requires downtime)

### Out of Disk Space

**Symptom**: `ERROR: could not extend file: No space left on device`

**Diagnosis**:
```bash
# Check available space
df -h /mnt/tank/maas/postgres

# Check database size
docker exec -t maas-postgres psql -U maas -d maasdb -c "SELECT pg_size_pretty(pg_database_size('maasdb'));"

# Check largest tables
docker exec -t maas-postgres psql -U maas -d maasdb -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
```

**Solutions**:

1. **Expand volume**: Increase TrueNAS dataset quota
2. **Clean old data**: Run VACUUM to reclaim space
3. **Archive old data**: Move historical data to separate storage

### High Memory Usage

**Symptom**: PostgreSQL consuming excessive RAM

**Diagnosis**:
```bash
# Check memory usage
docker stats maas-postgres

# Check PostgreSQL settings
docker exec -t maas-postgres psql -U maas -d maasdb -c "SHOW shared_buffers; SHOW effective_cache_size; SHOW work_mem;"
```

**Solutions**:

1. **Reduce shared_buffers**: Lower from 25% to 15% of RAM
2. **Reduce max_connections**: Fewer connections = less memory
3. **Reduce work_mem**: Lower per-operation memory
4. **Add memory limit**: In compose.yaml, add `mem_limit: 4g`

---

## Monitoring

### Key Metrics to Monitor

#### 1. Connection Count

**Why**: Approaching max_connections causes new connection rejections.

**Query**:
```sql
SELECT count(*) as connections,
       current_setting('max_connections')::int as max
FROM pg_stat_activity;
```

**Threshold**: Alert if > 80% of max_connections

#### 2. Database Size

**Why**: Predict when storage expansion is needed.

**Query**:
```sql
SELECT pg_size_pretty(pg_database_size('maasdb')) as size;
```

**Threshold**: Alert if > 80% of allocated storage

#### 3. Slow Queries

**Why**: Identify performance issues before they impact users.

**Query**:
```sql
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

**Threshold**: Alert if mean_time > 1000ms

**Note**: Requires `pg_stat_statements` extension

#### 4. Cache Hit Ratio

**Why**: Low cache hit ratio indicates insufficient memory.

**Query**:
```sql
SELECT
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit) as heap_hit,
  sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) as ratio
FROM pg_statio_user_tables;
```

**Threshold**: Alert if ratio < 0.95 (95%)

**Solution**: Increase shared_buffers

#### 5. Table Bloat

**Why**: Dead tuples waste space and slow queries.

**Query**:
```sql
SELECT schemaname, tablename, n_dead_tup, n_live_tup,
       round(n_dead_tup * 100.0 / nullif(n_live_tup + n_dead_tup, 0), 2) as dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

**Threshold**: Alert if dead_ratio > 10%

**Solution**: Adjust autovacuum settings or run manual VACUUM

#### 6. Replication Lag (if using HA)

**Why**: Large lag can cause data loss during failover.

**Query**:
```sql
SELECT client_addr, state,
       pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) as send_lag,
       pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as replay_lag
FROM pg_stat_replication;
```

**Threshold**: Alert if replay_lag > 100MB

### Monitoring Tools

#### 1. Built-in pg_stat Views

**Advantages**: No additional software required

**Example monitoring script**:
```bash
#!/bin/bash
# Monitor PostgreSQL health
docker exec -t maas-postgres psql -U maas -d maasdb <<EOF
\echo '=== Connection Count ==='
SELECT count(*) FROM pg_stat_activity;

\echo '=== Database Size ==='
SELECT pg_size_pretty(pg_database_size('maasdb'));

\echo '=== Cache Hit Ratio ==='
SELECT sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) as cache_ratio FROM pg_statio_user_tables;

\echo '=== Slow Queries (last hour) ==='
SELECT query, calls, mean_time FROM pg_stat_statements WHERE mean_time > 1000 ORDER BY mean_time DESC LIMIT 5;
EOF
```

#### 2. pg_stat_statements Extension

**Purpose**: Track query performance over time

**Enable**:
```sql
-- In postgresql.conf
shared_preload_libraries = 'pg_stat_statements'

-- In database
CREATE EXTENSION pg_stat_statements;
```

**Usage**:
```sql
-- Top 10 slowest queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

#### 3. External Monitoring (Optional)

**pgAdmin**: Web-based PostgreSQL management
- Dashboard with real-time metrics
- Query tool and explain analyzer
- Backup/restore management

**Grafana + Prometheus + postgres_exporter**: Comprehensive monitoring
- Historical metrics and trends
- Custom dashboards
- Alerting integration

**Example postgres_exporter service**:
```yaml
# Add to compose.yaml
postgres-exporter:
  image: prometheuscommunity/postgres-exporter:latest
  environment:
    DATA_SOURCE_NAME: "postgresql://maas:${POSTGRES_PASSWORD}@postgres:5432/maasdb?sslmode=disable"
  ports:
    - "9187:9187"
  networks:
    - maas-internal
```

---

## References

### TrueNAS and Docker

1. [Solutions for a container that requires UID and GID 568 - TrueNAS Community](https://forums.truenas.com/t/solutions-for-a-container-that-requires-uid-and-gid-1000/37436)
2. [Postgres app not running in Scale Electric Eel - TrueNAS Community](https://forums.truenas.com/t/postgres-app-not-running-in-scale-electric-eel/25203)
3. [Correct way of backing postgresql based apps - TrueNAS Community](https://www.truenas.com/community/threads/correct-way-of-backing-postgresql-based-apps.114680/)

### PostgreSQL Docker Issues

4. [Impossible to run with "--user" - docker-library/postgres Issue #589](https://github.com/docker-library/postgres/issues/589)
5. [associate --user id with the internal postgres user id - docker-library/postgres Issue #1260](https://github.com/docker-library/postgres/issues/1260)
6. [rootless container permission error - docker-library/postgres Issue #1287](https://github.com/docker-library/postgres/issues/1287)

### PostgreSQL Performance Tuning

7. [PostgreSQL Performance Tuning Guide - Percona](https://www.percona.com/blog/tuning-postgresql-database-parameters-to-optimize-performance/)
8. [Tuning Your PostgreSQL Server - PostgreSQL Wiki](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
9. [PostgreSQL Performance Tuning Best Practices 2025 - MyDBOps](https://www.mydbops.com/blog/postgresql-parameter-tuning-best-practices)

### PostgreSQL Backup Strategies

10. [Docker Postgres Backup/Restore Guide - SimpleBackups](https://simplebackups.com/blog/docker-postgres-backup-restore-guide-with-examples)
11. [Backup and Restore Immich from TrueNAS Scale to Docker - GitHub](https://github.com/immich-app/immich/discussions/10906)
12. [Implementing PostgreSQL Backup and Restore Plan - Medium](https://medium.com/@heidarbozorg/postgresql-backup-and-restore-strategy-abaa0ccb8d93)

### MAAS and PostgreSQL

13. [How to get MAAS up and running - Canonical](https://canonical.com/maas/docs/how-to-get-maas-up-and-running)
14. [maas-docs/manage-ha-postgresql.md - GitHub](https://github.com/CanonicalLtd/maas-docs/blob/master/en/manage-ha-postgresql.md)

### Docker Non-Root Users

15. [How to Run Docker Containers as Non-Root Users - OneUpTime](https://oneuptime.com/blog/post/2026-01-16-docker-run-non-root-user/view)
16. [Running Docker Containers as a Non-root User - Nick Janetakis](https://nickjanetakis.com/blog/running-docker-containers-as-a-non-root-user-with-a-custom-uid-and-gid)

---

## Summary

This PostgreSQL setup provides:

- ✅ **TrueNAS 25.10+ Compatibility**: Runs with uid/gid 568
- ✅ **Production-Ready Performance**: Optimized for MAAS workloads
- ✅ **Automated Initialization**: Database setup is automatic
- ✅ **Comprehensive Backup Strategy**: Multiple backup methods supported
- ✅ **Extensive Documentation**: Troubleshooting and monitoring covered
- ✅ **Security Best Practices**: Non-root operation, minimal privileges

For questions or issues, refer to the troubleshooting section or consult the TrueNAS community forums.
