#!/bin/bash
#
# PostgreSQL Backup Script for TrueNAS MAAS Application
# This script creates logical backups of the PostgreSQL database
#
# Usage: ./scripts/backup-postgres.sh [backup_dir]
# Example: ./scripts/backup-postgres.sh /mnt/tank/backups/maas
#

set -e

# Configuration
BACKUP_DIR="${1:-/mnt/tank/backups/maas}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CONTAINER_NAME="maas-postgres"
DB_USER="${POSTGRES_USER:-maas}"
DB_NAME="${POSTGRES_DB:-maasdb}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "PostgreSQL container '${CONTAINER_NAME}' is not running"
        exit 1
    fi
    log_info "PostgreSQL container is running"
}

# Create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi

    if [ ! -w "$BACKUP_DIR" ]; then
        log_error "Backup directory is not writable: $BACKUP_DIR"
        exit 1
    fi
}

# Perform backup
perform_backup() {
    local backup_file="$BACKUP_DIR/maasdb-backup-${TIMESTAMP}.sql.gz"
    local schema_file="$BACKUP_DIR/maasdb-schema-${TIMESTAMP}.sql.gz"

    log_info "Starting database backup..."
    log_info "Backup file: $backup_file"

    # Full database backup
    if docker exec -t "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$backup_file"; then
        local size=$(du -h "$backup_file" | cut -f1)
        log_info "Database backup completed: $backup_file ($size)"
    else
        log_error "Database backup failed"
        exit 1
    fi

    # Schema-only backup (for reference)
    log_info "Creating schema backup..."
    if docker exec -t "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" --schema-only | gzip > "$schema_file"; then
        local schema_size=$(du -h "$schema_file" | cut -f1)
        log_info "Schema backup completed: $schema_file ($schema_size)"
    else
        log_warn "Schema backup failed (non-critical)"
    fi
}

# Verify backup
verify_backup() {
    local backup_file="$BACKUP_DIR/maasdb-backup-${TIMESTAMP}.sql.gz"

    log_info "Verifying backup integrity..."

    # Check if file exists and is not empty
    if [ ! -s "$backup_file" ]; then
        log_error "Backup file is empty or does not exist"
        exit 1
    fi

    # Test gzip integrity
    if ! gunzip -t "$backup_file" 2>/dev/null; then
        log_error "Backup file is corrupted (gzip test failed)"
        exit 1
    fi

    log_info "Backup verification successful"
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."

    local count=$(find "$BACKUP_DIR" -name "maasdb-backup-*.sql.gz" -type f -mtime +$RETENTION_DAYS | wc -l)

    if [ "$count" -gt 0 ]; then
        find "$BACKUP_DIR" -name "maasdb-backup-*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
        find "$BACKUP_DIR" -name "maasdb-schema-*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
        log_info "Removed $count old backup(s)"
    else
        log_info "No old backups to clean up"
    fi
}

# Generate backup report
generate_report() {
    log_info "=== Backup Report ==="
    echo ""
    echo "Timestamp: $(date)"
    echo "Backup Directory: $BACKUP_DIR"
    echo ""
    echo "Recent Backups:"
    ls -lh "$BACKUP_DIR"/maasdb-backup-*.sql.gz 2>/dev/null | tail -5 || echo "No backups found"
    echo ""
    echo "Disk Usage:"
    du -sh "$BACKUP_DIR"
    echo ""
    echo "Available Space:"
    df -h "$BACKUP_DIR" | tail -1
    echo ""
}

# Main execution
main() {
    log_info "=== PostgreSQL Backup Script ==="
    log_info "Starting backup at $(date)"

    check_container
    create_backup_dir
    perform_backup
    verify_backup
    cleanup_old_backups
    generate_report

    log_info "Backup completed successfully at $(date)"
}

# Run main function
main "$@"
