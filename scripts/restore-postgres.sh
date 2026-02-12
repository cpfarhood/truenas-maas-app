#!/bin/bash
#
# PostgreSQL Restore Script for TrueNAS MAAS Application
# This script restores a PostgreSQL database from a backup
#
# Usage: ./scripts/restore-postgres.sh <backup_file>
# Example: ./scripts/restore-postgres.sh /mnt/tank/backups/maas/maasdb-backup-20260212-100000.sql.gz
#

set -e

# Configuration
BACKUP_FILE="$1"
CONTAINER_NAME="maas-postgres"
MAAS_CONTAINER="maas-region"
DB_USER="${POSTGRES_USER:-maas}"
DB_NAME="${POSTGRES_DB:-maasdb}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Usage information
show_usage() {
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/tank/backups/maas/maasdb-backup-20260212-100000.sql.gz"
    echo "  $0 ./maasdb-backup-20260212-100000.sql.gz"
    echo ""
    echo "Available backups:"
    ls -lh /mnt/tank/backups/maas/maasdb-backup-*.sql.gz 2>/dev/null || echo "  No backups found in /mnt/tank/backups/maas/"
    exit 1
}

# Check arguments
check_arguments() {
    if [ -z "$BACKUP_FILE" ]; then
        log_error "No backup file specified"
        show_usage
    fi

    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file does not exist: $BACKUP_FILE"
        exit 1
    fi

    if [ ! -r "$BACKUP_FILE" ]; then
        log_error "Backup file is not readable: $BACKUP_FILE"
        exit 1
    fi

    log_info "Backup file: $BACKUP_FILE"
    log_info "File size: $(du -h "$BACKUP_FILE" | cut -f1)"
}

# Verify backup integrity
verify_backup() {
    log_step "Verifying backup file integrity..."

    if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
        log_error "Backup file is corrupted (gzip test failed)"
        exit 1
    fi

    log_info "Backup file integrity verified"
}

# Check if containers are running
check_containers() {
    log_step "Checking container status..."

    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "PostgreSQL container '${CONTAINER_NAME}' is not running"
        log_info "Start it with: docker compose up -d postgres"
        exit 1
    fi

    log_info "PostgreSQL container is running"
}

# Confirm restore operation
confirm_restore() {
    log_warn "=========================================="
    log_warn "WARNING: This will REPLACE the current database!"
    log_warn "=========================================="
    echo ""
    echo "Database: $DB_NAME"
    echo "Backup file: $BACKUP_FILE"
    echo "Backup date: $(stat -c %y "$BACKUP_FILE" 2>/dev/null || stat -f "%Sm" "$BACKUP_FILE" 2>/dev/null)"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled by user"
        exit 0
    fi
}

# Stop MAAS service
stop_maas() {
    log_step "Stopping MAAS service..."

    if docker ps --format '{{.Names}}' | grep -q "^${MAAS_CONTAINER}$"; then
        docker compose stop maas
        log_info "MAAS service stopped"
    else
        log_info "MAAS service is not running"
    fi
}

# Create database backup before restore
create_safety_backup() {
    log_step "Creating safety backup of current database..."

    local safety_backup="/tmp/maasdb-pre-restore-$(date +%Y%m%d-%H%M%S).sql.gz"

    if docker exec -t "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$safety_backup"; then
        log_info "Safety backup created: $safety_backup"
        log_info "Keep this file in case you need to rollback"
    else
        log_warn "Could not create safety backup (database may be empty)"
    fi
}

# Drop and recreate database
recreate_database() {
    log_step "Recreating database..."

    # Terminate active connections
    log_info "Terminating active connections to $DB_NAME..."
    docker exec -t "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres <<-EOSQL 2>/dev/null || true
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
EOSQL

    # Drop database
    log_info "Dropping database $DB_NAME..."
    docker exec -t "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" || {
        log_error "Failed to drop database"
        exit 1
    }

    # Recreate database
    log_info "Creating database $DB_NAME..."
    docker exec -t "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER;" || {
        log_error "Failed to create database"
        exit 1
    }

    log_info "Database recreated successfully"
}

# Restore database
restore_database() {
    log_step "Restoring database from backup..."

    local start_time=$(date +%s)

    if gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" 2>&1 | tee /tmp/restore.log; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_info "Database restored successfully in ${duration}s"
    else
        log_error "Database restore failed"
        log_error "Check /tmp/restore.log for details"
        exit 1
    fi
}

# Verify restore
verify_restore() {
    log_step "Verifying database restore..."

    # Check if database exists
    if ! docker exec -t "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        log_error "Database verification failed - database not accessible"
        exit 1
    fi

    # Get table count
    local table_count=$(docker exec -t "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d '[:space:]')

    log_info "Database contains $table_count tables"

    if [ "$table_count" -eq 0 ]; then
        log_warn "Database appears to be empty"
    else
        log_info "Database verification successful"
    fi
}

# Restart MAAS service
restart_maas() {
    log_step "Starting MAAS service..."

    docker compose start maas

    log_info "Waiting for MAAS to be ready..."
    sleep 5

    if docker ps --format '{{.Names}}' | grep -q "^${MAAS_CONTAINER}$"; then
        log_info "MAAS service started"
    else
        log_warn "MAAS service may have failed to start"
        log_info "Check logs with: docker compose logs maas"
    fi
}

# Generate restore report
generate_report() {
    log_info "=== Restore Report ==="
    echo ""
    echo "Timestamp: $(date)"
    echo "Backup File: $BACKUP_FILE"
    echo "Database: $DB_NAME"
    echo ""
    echo "Database Statistics:"
    docker exec -t "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" <<-EOSQL
        SELECT
            'Tables' as type,
            count(*) as count
        FROM information_schema.tables
        WHERE table_schema = 'public'
        UNION ALL
        SELECT
            'Indexes' as type,
            count(*) as count
        FROM pg_indexes
        WHERE schemaname = 'public'
        UNION ALL
        SELECT
            'Size' as type,
            pg_size_pretty(pg_database_size('$DB_NAME'))::text as count;
EOSQL
    echo ""
}

# Main execution
main() {
    log_info "=== PostgreSQL Restore Script ==="
    log_info "Starting restore at $(date)"

    check_arguments
    verify_backup
    check_containers
    confirm_restore
    stop_maas
    create_safety_backup
    recreate_database
    restore_database
    verify_restore
    restart_maas
    generate_report

    log_info "Restore completed successfully at $(date)"
    echo ""
    log_info "Next steps:"
    echo "  1. Verify MAAS is functioning: docker compose logs -f maas"
    echo "  2. Access MAAS UI and confirm data is correct"
    echo "  3. If needed, safety backup is at: /tmp/maasdb-pre-restore-*.sql.gz"
}

# Run main function
main "$@"
