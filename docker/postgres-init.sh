#!/bin/bash
# PostgreSQL Initialization Script for MAAS Database
# This script runs automatically during first database initialization
# It sets up the MAAS database with optimal settings

set -e

# Function to log messages
log() {
    echo "[MAAS-INIT] $*"
}

log "Starting MAAS database initialization"

# Check if we're running during database initialization
if [ "$1" = "postgres" ]; then
    log "Detected PostgreSQL initialization phase"
fi

# Wait for PostgreSQL to be ready
until psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c '\q' 2>/dev/null; do
    log "Waiting for PostgreSQL to be ready..."
    sleep 1
done

log "PostgreSQL is ready, configuring MAAS database"

# Create extensions that MAAS may use
log "Creating PostgreSQL extensions for MAAS"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
    -- Enable required extensions for MAAS
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";

    -- Grant necessary privileges
    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};

    -- Optimize for MAAS workload
    ALTER DATABASE ${POSTGRES_DB} SET synchronous_commit = 'off';
    ALTER DATABASE ${POSTGRES_DB} SET full_page_writes = 'on';

    -- Set connection limits if needed
    ALTER ROLE ${POSTGRES_USER} CONNECTION LIMIT -1;
EOSQL

log "MAAS database initialization completed successfully"

# Create a marker file to indicate initialization is complete
touch /var/lib/postgresql/data/.maas-initialized

log "MAAS PostgreSQL initialization script finished"
