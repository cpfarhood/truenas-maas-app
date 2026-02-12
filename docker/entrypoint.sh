#!/bin/bash
# TrueNAS MAAS Application - Entrypoint Script
# Version: 1.0.0
# Handles MAAS initialization, database setup, and service startup

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    local max_attempts=30
    local attempt=1

    log_info "Waiting for PostgreSQL to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if pg_isready -h "${POSTGRES_HOST:-postgres}" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-maas}" > /dev/null 2>&1; then
            log_success "PostgreSQL is ready!"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts: PostgreSQL not ready yet, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "PostgreSQL did not become ready after $max_attempts attempts"
    return 1
}

# Function to check if MAAS database is initialized
is_database_initialized() {
    PGPASSWORD="${POSTGRES_PASSWORD}" psql \
        -h "${POSTGRES_HOST:-postgres}" \
        -p "${POSTGRES_PORT:-5432}" \
        -U "${POSTGRES_USER:-maas}" \
        -d "${POSTGRES_DB:-maasdb}" \
        -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null || echo "0"
}

# Function to initialize MAAS database
initialize_database() {
    log_info "Initializing MAAS database..."

    # Check if database already has tables
    local table_count=$(is_database_initialized)

    if [ "$table_count" -gt "0" ]; then
        log_info "Database already initialized with $table_count tables, skipping initialization"
        return 0
    fi

    log_info "Database is empty, running MAAS database migrations..."

    # Set database connection string
    export DATABASE_HOST="${POSTGRES_HOST:-postgres}"
    export DATABASE_PORT="${POSTGRES_PORT:-5432}"
    export DATABASE_NAME="${POSTGRES_DB:-maasdb}"
    export DATABASE_USER="${POSTGRES_USER:-maas}"
    export DATABASE_PASS="${POSTGRES_PASSWORD}"

    # Create MAAS database configuration
    mkdir -p /etc/maas
    cat > /etc/maas/regiond.conf <<EOF
database_host: ${DATABASE_HOST}
database_port: ${DATABASE_PORT}
database_name: ${DATABASE_NAME}
database_user: ${DATABASE_USER}
database_pass: ${DATABASE_PASS}
maas_url: ${MAAS_URL}
EOF

    # Run database migrations
    if sudo -E maas-region dbupgrade; then
        log_success "Database migrations completed successfully"
    else
        log_error "Database migrations failed"
        return 1
    fi

    return 0
}

# Function to create MAAS admin user
create_admin_user() {
    log_info "Checking for MAAS admin user..."

    # Check if admin user already exists
    if sudo maas-region shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(username='${MAAS_ADMIN_USERNAME:-admin}').exists())" 2>/dev/null | grep -q "True"; then
        log_info "Admin user '${MAAS_ADMIN_USERNAME:-admin}' already exists"
        return 0
    fi

    log_info "Creating MAAS admin user '${MAAS_ADMIN_USERNAME:-admin}'..."

    # Create admin user
    if sudo maas-region createadmin \
        --username "${MAAS_ADMIN_USERNAME:-admin}" \
        --password "${MAAS_ADMIN_PASSWORD}" \
        --email "${MAAS_ADMIN_EMAIL}" \
        --ssh-import ""; then
        log_success "Admin user created successfully"
    else
        log_error "Failed to create admin user"
        return 1
    fi

    return 0
}

# Function to configure MAAS settings
configure_maas() {
    log_info "Configuring MAAS settings..."

    # Set MAAS URL
    if [ -n "${MAAS_URL}" ]; then
        log_info "Setting MAAS URL to: ${MAAS_URL}"
        sudo maas-region local_config_set --maas-url "${MAAS_URL}" || log_warning "Failed to set MAAS URL"
    fi

    # Configure DNS forwarder
    if [ -n "${MAAS_DNS_FORWARDER}" ]; then
        log_info "Setting DNS forwarder to: ${MAAS_DNS_FORWARDER}"
        # This will be configured via API after service starts
    fi

    # Set region secret if provided
    if [ -n "${MAAS_REGION_SECRET}" ]; then
        log_info "Setting MAAS region secret..."
        echo "${MAAS_REGION_SECRET}" | sudo tee /var/lib/maas/secret > /dev/null
        sudo chmod 640 /var/lib/maas/secret
    fi

    log_success "MAAS configuration completed"
}

# Function to start MAAS services
start_maas_services() {
    log_info "Starting MAAS region controller services..."

    # MAAS 3.x services need to be started via systemd or run directly
    # In a container without systemd, we'll start them in the background

    # Start MAASregion D API server (background)
    log_info "Starting MAAS regiond service..."
    sudo -E -u maas PYTHONPATH=/usr/lib/python3/dist-packages maas-regiond serve --worker-threads 4 > /var/log/maas/regiond.log 2>&1 &
    REGIOND_PID=$!

    # Give it a moment to start
    sleep 3

    # Check if process is still running
    if ! kill -0 $REGIOND_PID 2>/dev/null; then
        log_error "Failed to start MAAS region controller"
        return 1
    fi

    log_success "MAAS regiond started (PID: $REGIOND_PID)"

    return 0
}

# Function to import boot images (if enabled)
import_boot_images() {
    if [ "${MAAS_BOOT_IMAGES_AUTO_IMPORT:-true}" = "true" ]; then
        log_info "Auto-import of boot images is enabled"
        log_info "Boot images will be imported in the background"
        log_info "This process can take 30-60 minutes depending on your internet connection"
        log_info "Monitor progress in MAAS UI: Images section"
    else
        log_info "Auto-import of boot images is disabled"
        log_info "You will need to manually import boot images from the MAAS UI"
    fi
}

# Main initialization function
main() {
    log_info "============================================"
    log_info "MAAS Region Controller Initialization"
    log_info "Version: 1.0.0"
    log_info "TrueNAS MAAS Application"
    log_info "============================================"

    # Display configuration
    log_info "Configuration:"
    log_info "  - MAAS URL: ${MAAS_URL}"
    log_info "  - Admin Username: ${MAAS_ADMIN_USERNAME:-admin}"
    log_info "  - Admin Email: ${MAAS_ADMIN_EMAIL}"
    log_info "  - Database Host: ${POSTGRES_HOST:-postgres}"
    log_info "  - Database Name: ${POSTGRES_DB:-maasdb}"
    log_info "  - Database User: ${POSTGRES_USER:-maas}"
    log_info "  - Debug Mode: ${MAAS_DEBUG:-false}"

    # Wait for PostgreSQL
    if ! wait_for_postgres; then
        log_error "Failed to connect to PostgreSQL"
        exit 1
    fi

    # Check if this is first run
    local table_count=$(is_database_initialized)

    if [ "$table_count" = "0" ]; then
        log_info "First run detected - initializing MAAS..."

        # Initialize database
        if ! initialize_database; then
            log_error "Database initialization failed"
            exit 1
        fi

        # Create admin user
        if ! create_admin_user; then
            log_error "Admin user creation failed"
            exit 1
        fi

        # Configure MAAS
        configure_maas

        log_success "MAAS initialization completed successfully"
    else
        log_info "MAAS already initialized (found $table_count database tables)"
        log_info "Skipping initialization steps..."
    fi

    # Start MAAS services
    if ! start_maas_services; then
        log_error "Failed to start MAAS services"
        exit 1
    fi

    # Import boot images info
    import_boot_images

    log_success "============================================"
    log_success "MAAS Region Controller Ready"
    log_success "Web UI: ${MAAS_URL}"
    log_success "Username: ${MAAS_ADMIN_USERNAME:-admin}"
    log_success "============================================"

    # Keep container running and tail logs
    log_info "Monitoring MAAS logs (Ctrl+C to view container logs)..."
    tail -f /var/log/maas/regiond.log /var/log/maas/maas.log 2>/dev/null || {
        log_info "Log files not available yet, waiting for MAAS to create them..."
        # Keep container running
        while true; do
            sleep 60
            if [ -f /var/log/maas/regiond.log ]; then
                tail -f /var/log/maas/regiond.log /var/log/maas/maas.log 2>/dev/null || sleep 60
            fi
        done
    }
}

# Handle signals for graceful shutdown
trap 'log_info "Received shutdown signal, stopping MAAS..."; killall maas-regiond 2>/dev/null; exit 0' SIGTERM SIGINT

# Run main function
main "$@"
