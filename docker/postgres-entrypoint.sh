#!/bin/bash
# PostgreSQL Entrypoint Wrapper for TrueNAS uid/gid 568
# This script ensures proper permissions before starting PostgreSQL

set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to fix permissions
fix_permissions() {
    local target_dir="$1"

    if [ -d "$target_dir" ]; then
        log "Fixing permissions for $target_dir"

        # Check current ownership
        current_owner=$(stat -c '%u:%g' "$target_dir" 2>/dev/null || stat -f '%u:%g' "$target_dir" 2>/dev/null || echo "unknown")
        log "Current ownership of $target_dir: $current_owner"

        # If we're running as uid 568 (which we should be), ensure the directory is owned by us
        if [ "$(id -u)" = "568" ]; then
            # Only fix ownership if the directory is empty or already owned by 568
            # This prevents data corruption if there's existing data with different ownership
            if [ -z "$(ls -A "$target_dir")" ] || [ "$current_owner" = "568:568" ] || [ "$current_owner" = "999:999" ]; then
                chown -R 568:568 "$target_dir" 2>/dev/null || {
                    log "Warning: Could not change ownership of $target_dir (may already be correct)"
                }
                chmod 700 "$target_dir" 2>/dev/null || {
                    log "Warning: Could not change permissions of $target_dir (may already be correct)"
                }
            else
                log "Warning: $target_dir has unexpected ownership ($current_owner). Skipping ownership change to prevent data corruption."
                log "If this is a new installation, please ensure the volume is owned by uid/gid 568:568"
            fi
        fi
    fi
}

log "Starting PostgreSQL entrypoint wrapper for TrueNAS uid/gid 568"
log "Running as user: $(id -u):$(id -g)"
log "PGDATA: ${PGDATA:-/var/lib/postgresql/data/pgdata}"

# Ensure PGDATA is set
export PGDATA="${PGDATA:-/var/lib/postgresql/data/pgdata}"

# Create PGDATA parent directory if it doesn't exist
mkdir -p "$(dirname "$PGDATA")" 2>/dev/null || true

# Fix permissions on key directories
fix_permissions "$PGDATA"
fix_permissions "/var/lib/postgresql/data"
fix_permissions "/var/run/postgresql"

# If PGDATA doesn't exist or is empty, create it
if [ ! -d "$PGDATA" ]; then
    log "Creating PGDATA directory: $PGDATA"
    mkdir -p "$PGDATA"
    chown -R 568:568 "$PGDATA" 2>/dev/null || true
    chmod 700 "$PGDATA"
fi

# Check if this is a first run (database not initialized)
if [ -z "$(ls -A "$PGDATA")" ]; then
    log "PGDATA is empty - PostgreSQL will initialize a new database cluster"

    # Ensure we have required environment variables for initialization
    if [ -z "$POSTGRES_PASSWORD" ] && [ -z "$POSTGRES_HOST_AUTH_METHOD" ]; then
        log "ERROR: No password set and POSTGRES_HOST_AUTH_METHOD not set to 'trust'"
        log "You must set POSTGRES_PASSWORD environment variable"
        exit 1
    fi

    log "Database initialization will proceed with official PostgreSQL entrypoint"
else
    log "PGDATA contains data - using existing database cluster"
fi

# Call the official PostgreSQL entrypoint
# We use exec to replace the shell process with postgres
log "Transferring control to official PostgreSQL entrypoint"
exec docker-entrypoint.sh "$@"
