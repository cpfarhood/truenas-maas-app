# PostgreSQL Implementation Validation Checklist

This checklist validates the PostgreSQL implementation for TrueNAS MAAS application. Complete all items before production deployment.

**Validator**: _______________
**Date**: _______________
**Environment**: [ ] Development [ ] Staging [ ] Production

---

## Pre-Deployment Validation

### File Verification

- [ ] `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/docker/postgres.Dockerfile` exists and is readable
- [ ] `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/docker/postgres-entrypoint.sh` exists and is executable
- [ ] `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/docker/postgres-init.sh` exists and is executable
- [ ] `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/docker/postgresql.conf` exists and is readable
- [ ] `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/scripts/backup-postgres.sh` exists and is executable
- [ ] `/Users/cpfarhood/Documents/Repositories/truenas-maas-app/scripts/restore-postgres.sh` exists and is executable

**Validation Command**:
```bash
ls -lh docker/postgres* scripts/*postgres*.sh
```

**Expected Result**: All files present with correct permissions (scripts with `x` flag)

---

### Configuration Verification

- [ ] `compose.yaml` has custom PostgreSQL build configuration
- [ ] `compose.yaml` specifies `user: "568:568"` for postgres service
- [ ] `compose.yaml` includes `shm_size: 256mb` for postgres service
- [ ] `.env.example` includes PostgreSQL-specific variables
- [ ] POSTGRES_PASSWORD is set in `.env` file (not committed to git)

**Validation Command**:
```bash
grep -A 10 "postgres:" compose.yaml | grep -E "(build:|user:|shm_size:)"
grep POSTGRES .env.example
```

**Expected Result**: Build configuration, user 568:568, and shm_size present

---

### Documentation Verification

- [ ] POSTGRESQL-SETUP.md exists and contains troubleshooting section
- [ ] POSTGRESQL-SETUP.md includes performance tuning guidelines
- [ ] POSTGRESQL-SETUP.md references all research sources
- [ ] scripts/README.md documents backup/restore procedures
- [ ] POSTGRESQL-IMPLEMENTATION-SUMMARY.md provides complete overview

**Validation Command**:
```bash
wc -l POSTGRESQL-*.md scripts/README.md
```

**Expected Result**: Comprehensive documentation (1000+ lines total)

---

## Build Validation

### Docker Image Build

- [ ] Custom PostgreSQL image builds without errors
- [ ] Build completes in reasonable time (<5 minutes)
- [ ] Image size is reasonable (<200MB for Alpine-based)
- [ ] Image is tagged correctly (truenas-maas-postgres:15)

**Validation Command**:
```bash
docker compose build postgres
docker images | grep truenas-maas-postgres
```

**Expected Result**:
```
truenas-maas-postgres   15      <image_id>   <timestamp>   ~150MB
```

### Image Inspection

- [ ] Postgres user exists with uid 568
- [ ] Postgres group exists with gid 568
- [ ] Required directories exist: `/var/lib/postgresql/data`, `/var/run/postgresql`
- [ ] Custom scripts are present in image
- [ ] Entrypoint is set correctly

**Validation Command**:
```bash
docker run --rm truenas-maas-postgres:15 id postgres
docker run --rm truenas-maas-postgres:15 ls -la /var/lib/postgresql/data
docker run --rm truenas-maas-postgres:15 ls -la /usr/local/bin/postgres-entrypoint.sh
```

**Expected Result**:
- uid=1000(postgres) gid=1000(postgres)
- Directories owned by postgres:postgres
- Entrypoint script executable

---

## Deployment Validation

### Storage Preparation

- [ ] PostgreSQL data directory created: `/mnt/tank/maas/postgres` (or configured path)
- [ ] Directory owned by uid/gid 568:1000
- [ ] Directory permissions set to 700
- [ ] At least 20GB free space available

**Validation Command**:
```bash
sudo mkdir -p /mnt/tank/maas/postgres
sudo chown -R 568:568 /mnt/tank/maas/postgres
sudo chmod 700 /mnt/tank/maas/postgres
df -h /mnt/tank/maas/postgres
```

**Expected Result**: Directory exists, correct ownership, sufficient space

### Initial Startup

- [ ] PostgreSQL container starts successfully
- [ ] No permission errors in logs
- [ ] Database initialization completes
- [ ] Container reaches "healthy" status
- [ ] MAAS-specific extensions created (uuid-ossp, pg_trgm)

**Validation Command**:
```bash
docker compose up -d postgres
sleep 30
docker compose ps postgres
docker compose logs postgres | grep -i error
docker exec -t maas-postgres psql -U maas -d maasdb -c "\dx"
```

**Expected Result**:
- Container status: Up (healthy)
- No critical errors in logs
- Extensions listed: uuid-ossp, pg_trgm

---

## Functional Validation

### Database Connectivity

- [ ] MAAS can connect to PostgreSQL
- [ ] Test query executes successfully
- [ ] Connection pool is functional
- [ ] No authentication errors

**Validation Command**:
```bash
docker compose up -d maas
sleep 30
docker compose logs maas | grep -i database
docker exec -t maas-postgres psql -U maas -d maasdb -c "SELECT version();"
```

**Expected Result**:
- MAAS connects successfully
- PostgreSQL version displayed
- No connection errors

### Write Operations

- [ ] Can create tables
- [ ] Can insert data
- [ ] Can update data
- [ ] Can delete data
- [ ] Transactions work correctly

**Validation Command**:
```bash
docker exec -t maas-postgres psql -U maas -d maasdb <<EOF
CREATE TABLE validation_test (id INT PRIMARY KEY, data TEXT);
INSERT INTO validation_test VALUES (1, 'test');
UPDATE validation_test SET data = 'updated' WHERE id = 1;
SELECT * FROM validation_test;
DELETE FROM validation_test WHERE id = 1;
DROP TABLE validation_test;
EOF
```

**Expected Result**: All operations succeed without errors

### Read Operations

- [ ] Can query tables
- [ ] Indexes are used (EXPLAIN shows index scans)
- [ ] Query performance acceptable (<100ms for simple queries)

**Validation Command**:
```bash
docker exec -t maas-postgres psql -U maas -d maasdb -c "
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public'
LIMIT 5;"
```

**Expected Result**: Tables listed (after MAAS initialization)

---

## Performance Validation

### Configuration Loading

- [ ] Custom postgresql.conf is loaded
- [ ] shared_buffers matches configuration (2GB default)
- [ ] effective_cache_size matches configuration (6GB default)
- [ ] work_mem matches configuration (20MB default)
- [ ] autovacuum is enabled

**Validation Command**:
```bash
docker exec -t maas-postgres psql -U maas -d maasdb -c "
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW work_mem;
SHOW autovacuum;
"
```

**Expected Result**: Values match postgresql.conf settings

### Resource Usage

- [ ] Memory usage is within expected range (shared_buffers + ~500MB overhead)
- [ ] CPU usage is reasonable (<50% during idle)
- [ ] I/O operations are normal

**Validation Command**:
```bash
docker stats maas-postgres --no-stream
```

**Expected Result**:
- Memory: ~2.5GB (with 2GB shared_buffers)
- CPU: <10% idle, <80% under load

### Query Performance

- [ ] Simple queries: <10ms
- [ ] Complex joins: <100ms
- [ ] Large result sets: <1000ms
- [ ] No obvious slow queries in logs

**Validation Command**:
```bash
docker exec -t maas-postgres psql -U maas -d maasdb -c "
\timing on
SELECT count(*) FROM pg_stat_activity;
"
```

**Expected Result**: Query completes in <10ms

---

## Backup/Restore Validation

### Backup Script Testing

- [ ] Backup script runs without errors
- [ ] Backup file is created
- [ ] Backup file is not empty
- [ ] Backup file passes gzip integrity test
- [ ] Schema backup is created
- [ ] Backup size is reasonable

**Validation Command**:
```bash
./scripts/backup-postgres.sh /tmp/test-backup
ls -lh /tmp/test-backup/
gunzip -t /tmp/test-backup/maasdb-backup-*.sql.gz
```

**Expected Result**:
- Backup files created
- gzip test passes
- Size proportional to database content

### Restore Script Testing (Development Only!)

- [ ] Restore script runs without errors
- [ ] Safety backup is created before restore
- [ ] Database is recreated cleanly
- [ ] Data is restored correctly
- [ ] MAAS service restarts successfully

**Validation Command** (ONLY in dev/test environment):
```bash
# Create test data
docker exec -t maas-postgres psql -U maas -d maasdb -c "
CREATE TABLE restore_test (id INT PRIMARY KEY, created_at TIMESTAMP DEFAULT NOW());
INSERT INTO restore_test VALUES (1);
"

# Backup
./scripts/backup-postgres.sh /tmp/test-backup

# Restore
./scripts/restore-postgres.sh /tmp/test-backup/maasdb-backup-*.sql.gz

# Verify
docker exec -t maas-postgres psql -U maas -d maasdb -c "SELECT * FROM restore_test;"
```

**Expected Result**:
- Restore completes successfully
- Test data is present after restore

---

## Security Validation

### User Permissions

- [ ] PostgreSQL runs as uid 568 (verified with `id`)
- [ ] Non-root user confirmed
- [ ] Cannot escalate to root
- [ ] File permissions are restrictive (700 for data directory)

**Validation Command**:
```bash
docker exec -t maas-postgres id
docker exec -t maas-postgres whoami
docker exec -t maas-postgres ls -la /var/lib/postgresql/data
```

**Expected Result**:
- uid=1000(postgres) gid=1000(postgres)
- whoami shows "postgres"
- Data directory: drwx------ postgres postgres

### Container Security

- [ ] All capabilities dropped (except necessary ones)
- [ ] no-new-privileges security option set
- [ ] Container runs unprivileged
- [ ] No sensitive data in environment variables (passwords in .env only)

**Validation Command**:
```bash
docker inspect maas-postgres | grep -A 10 "CapDrop"
docker inspect maas-postgres | grep -i "Privileged"
docker inspect maas-postgres | grep -i "SecurityOpt"
```

**Expected Result**:
- CapDrop: ["ALL"]
- Privileged: false
- SecurityOpt: ["no-new-privileges:true"]

### Network Security

- [ ] PostgreSQL only accessible from maas-internal network
- [ ] Port 5432 not exposed to host (unless explicitly configured)
- [ ] No direct internet access required

**Validation Command**:
```bash
docker network inspect maas-internal | grep -A 5 maas-postgres
docker port maas-postgres
```

**Expected Result**:
- Container on maas-internal network
- No port mappings (unless bridge mode)

---

## High Availability Considerations (Optional)

### Replication Setup (if applicable)

- [ ] Streaming replication configured
- [ ] Replication user created
- [ ] WAL archiving enabled
- [ ] Standby server can connect
- [ ] Replication lag is minimal (<10MB)

**Validation Command** (if HA is configured):
```bash
docker exec -t maas-postgres psql -U maas -d maasdb -c "
SELECT client_addr, state, sync_state,
       pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as lag_bytes
FROM pg_stat_replication;
"
```

**Expected Result**: Replication active with minimal lag

---

## Monitoring Validation

### Logging

- [ ] PostgreSQL logs are accessible
- [ ] Log rotation is configured
- [ ] Slow queries are logged (>1000ms)
- [ ] Checkpoints are logged
- [ ] Connection events are logged

**Validation Command**:
```bash
docker compose logs postgres | tail -50
docker exec -t maas-postgres ls -la /var/lib/postgresql/data/log/
```

**Expected Result**: Logs present and rotated properly

### Metrics Collection (Optional)

- [ ] postgres_exporter configured (if using Prometheus)
- [ ] Metrics endpoint accessible
- [ ] Key metrics available (connections, cache hit ratio, etc.)

**Validation Command** (if metrics exporter is configured):
```bash
curl http://localhost:9187/metrics | grep pg_up
```

**Expected Result**: pg_up=1

---

## Documentation Validation

### User Documentation

- [ ] POSTGRESQL-SETUP.md is comprehensive and readable
- [ ] Troubleshooting section covers common issues
- [ ] Performance tuning section has clear examples
- [ ] Backup/restore procedures are documented
- [ ] All external references are linked

**Manual Review**: Read through POSTGRESQL-SETUP.md and verify clarity

### Operational Runbooks

- [ ] Backup procedure documented and tested
- [ ] Restore procedure documented and tested
- [ ] Emergency recovery procedure documented
- [ ] Monitoring guidelines documented

**Manual Review**: Walk through each runbook to verify completeness

---

## Integration Testing

### MAAS Integration

- [ ] MAAS successfully initializes database schema
- [ ] MAAS can perform node operations
- [ ] MAAS API responds correctly
- [ ] No database connection errors in MAAS logs

**Validation Command**:
```bash
docker compose logs maas | grep -i "database\|postgres" | tail -20
docker compose exec maas-region maas status
```

**Expected Result**: MAAS reports healthy database connection

### Multi-Service Operation

- [ ] Both postgres and maas services start in correct order
- [ ] Health checks pass for both services
- [ ] Services can restart without issues
- [ ] Dependencies are handled correctly (maas waits for postgres)

**Validation Command**:
```bash
docker compose down
docker compose up -d
sleep 60
docker compose ps
```

**Expected Result**: Both services "Up (healthy)"

---

## Stress Testing (Optional but Recommended)

### Connection Stress Test

- [ ] Can handle max_connections (100 concurrent)
- [ ] Graceful handling of connection exhaustion
- [ ] Performance remains stable under load

**Validation Command**:
```bash
# Using pgbench
docker exec -t maas-postgres pgbench -i -U maas maasdb
docker exec -t maas-postgres pgbench -c 50 -j 4 -t 1000 -U maas maasdb
```

**Expected Result**: Completes without errors, reasonable performance

### Data Volume Stress Test

- [ ] Can handle large tables (millions of rows)
- [ ] Autovacuum keeps up with churn
- [ ] Query performance remains acceptable

**Validation Command** (development only):
```bash
docker exec -t maas-postgres psql -U maas -d maasdb -c "
CREATE TABLE stress_test AS
SELECT generate_series(1, 1000000) as id,
       md5(random()::text) as data;
SELECT count(*) FROM stress_test;
EXPLAIN ANALYZE SELECT * FROM stress_test WHERE id = 500000;
DROP TABLE stress_test;
"
```

**Expected Result**: Operations complete in reasonable time

---

## Production Readiness Checklist

### Critical Items

- [ ] All validation tests passed
- [ ] Backup strategy implemented and tested
- [ ] Monitoring configured (logs at minimum)
- [ ] Documentation reviewed and approved
- [ ] Security hardening completed
- [ ] Performance tuning appropriate for environment

### Recommended Items

- [ ] Automated backups scheduled (cron/systemd timer)
- [ ] Metrics collection configured (Prometheus/Grafana)
- [ ] Alerting configured for critical events
- [ ] Disaster recovery plan documented
- [ ] High availability considered (if needed)
- [ ] Capacity planning documented

### Operations Readiness

- [ ] Operations team trained on backup/restore procedures
- [ ] Runbooks accessible to on-call staff
- [ ] Escalation procedures defined
- [ ] Change management process established
- [ ] Maintenance windows scheduled

---

## Sign-Off

### Validation Results

**Total Checks**: _________ / _________
**Pass Rate**: _________ %
**Critical Failures**: _________

**Comments**:
```
[Add any notes, concerns, or deviations here]
```

### Approvals

**Technical Lead**: _______________  Date: _______________

**Operations Lead**: _______________  Date: _______________

**Security Review**: _______________  Date: _______________

**Approved for Production**: [ ] YES [ ] NO [ ] WITH CONDITIONS

**Conditions** (if applicable):
```
[List any conditions that must be met before production deployment]
```

---

## Post-Deployment Validation

### 24-Hour Check

- [ ] No critical errors in logs
- [ ] Performance metrics within normal range
- [ ] No unplanned restarts
- [ ] Backup completed successfully

### 7-Day Check

- [ ] Database growth rate as expected
- [ ] Autovacuum performance acceptable
- [ ] No slow query accumulation
- [ ] Backup retention working correctly

### 30-Day Check

- [ ] Long-term performance stable
- [ ] Capacity planning on track
- [ ] No security incidents
- [ ] Operations team comfortable with procedures

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-12 | Initial | Initial validation checklist |

---

## Additional Resources

- **POSTGRESQL-SETUP.md**: Comprehensive PostgreSQL documentation
- **POSTGRESQL-IMPLEMENTATION-SUMMARY.md**: Implementation details and research
- **scripts/README.md**: Backup/restore script documentation
- **DOCKER-COMPOSE-README.md**: Overall application configuration
- **TrueNAS Community Forums**: https://forums.truenas.com/
