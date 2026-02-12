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

    # Validate required environment variables
    if [ -z "${MAAS_ADMIN_PASSWORD}" ]; then
        log_error "MAAS_ADMIN_PASSWORD is not set or empty"
        log_error "Please set MAAS_ADMIN_PASSWORD in your .env file"
        return 1
    fi

    if [ -z "${MAAS_ADMIN_EMAIL}" ]; then
        log_error "MAAS_ADMIN_EMAIL is not set or empty"
        log_error "Please set MAAS_ADMIN_EMAIL in your .env file"
        return 1
    fi

    # Check if admin user already exists
    if sudo maas-region shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(username='${MAAS_ADMIN_USERNAME:-admin}').exists())" 2>/dev/null | grep -q "True"; then
        log_info "Admin user '${MAAS_ADMIN_USERNAME:-admin}' already exists"
        return 0
    fi

    log_info "Creating MAAS admin user '${MAAS_ADMIN_USERNAME:-admin}'..."

    # Create admin user using Django shell
    # Export password to ensure it's available in sudo environment
    export MAAS_ADMIN_PASSWORD

    if sudo -E maas-region shell <<-'PYTHON' 2>&1 | grep -q "Admin user created successfully"
	from django.contrib.auth import get_user_model
	import os
	User = get_user_model()
	username = os.environ.get('MAAS_ADMIN_USERNAME', 'admin')
	email = os.environ['MAAS_ADMIN_EMAIL']
	password = os.environ['MAAS_ADMIN_PASSWORD']
	user = User.objects.create_superuser(
	    username=username,
	    email=email,
	    password=password
	)
	print('Admin user created successfully')
	PYTHON
    then
        log_success "Admin user '${MAAS_ADMIN_USERNAME:-admin}' created successfully"
        log_info "Email: ${MAAS_ADMIN_EMAIL}"
    else
        log_error "Failed to create admin user"
        log_error "Please check MAAS_ADMIN_PASSWORD and MAAS_ADMIN_EMAIL in your .env file"
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
# NOTE: With systemd, we don't need to manually start services
# Systemd will automatically start enabled services based on their unit files
start_maas_services() {
    log_info "MAAS services will be started by systemd"
    return 0
}

# NOTE: Nginx config wrapper generation moved to systemd service (maas-nginx-setup.service)
# This runs automatically after maas-regiond starts and before maas-http starts

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
    # Configure bind9 to run as maas user
    # This must run on EVERY start, not just first initialization
    # Package installation overwrites /etc/default/named on first start
    log_info "Configuring bind9 to run as maas user..."
    sed -i 's/-u bind/-u maas/' /etc/default/named

    # Configure chrony systemd service for proper status reporting
    # This fixes the "Dead" status in MAAS UI while chrony is actually running
    log_info "Configuring chrony systemd service..."
    mkdir -p /etc/systemd/system/chrony.service.d
    cat > /etc/systemd/system/chrony.service.d/override.conf << 'EOF'
[Service]
Type=forking
PIDFile=/run/chrony/chronyd.pid
Restart=on-failure
RestartSec=5
EOF

    # Ensure chrony PID directory exists with correct permissions
    mkdir -p /run/chrony
    chown ${MAAS_UID:-568}:${MAAS_GID:-568} /run/chrony

    # Create required MAAS directories that may be masked by volume mounts
    # These must exist for MAAS to start properly
    log_info "Ensuring required MAAS directories exist..."
    mkdir -p /var/lib/maas/certificates \
             /var/lib/maas/http \
             /var/lib/maas/image-storage/bootloaders \
             /var/lib/maas/prometheus
    chown -R ${MAAS_UID:-568}:${MAAS_GID:-568} \
             /var/lib/maas/certificates \
             /var/lib/maas/http \
             /var/lib/maas/image-storage \
             /var/lib/maas/prometheus

    # Check if initialization has already been completed
    # This marker file prevents re-initialization on container restarts
    local init_marker="/var/lib/maas/.initialized"

    if [ -f "$init_marker" ]; then
        log_info "============================================"
        log_info "MAAS Already Initialized - Starting systemd"
        log_info "============================================"
        log_info "Initialization marker found at: $init_marker"
        log_info "Skipping initialization, handing control to systemd..."
        log_info "Nginx config wrapper will be generated by systemd service"

        # Exec systemd directly - this replaces the current process
        exec /sbin/init --log-target=console 3>&1
    fi

    log_info "============================================"
    log_info "MAAS Region Controller Initialization"
    log_info "Version: 1.0.0"
    log_info "TrueNAS MAAS Application"
    log_info "============================================"

    # Validate required environment variables
    local validation_failed=0

    if [ -z "${MAAS_URL}" ]; then
        log_error "MAAS_URL is not set"
        validation_failed=1
    fi

    if [ -z "${MAAS_ADMIN_PASSWORD}" ]; then
        log_error "MAAS_ADMIN_PASSWORD is not set or empty"
        validation_failed=1
    fi

    if [ -z "${MAAS_ADMIN_EMAIL}" ]; then
        log_error "MAAS_ADMIN_EMAIL is not set or empty"
        validation_failed=1
    fi

    if [ -z "${POSTGRES_PASSWORD}" ]; then
        log_error "POSTGRES_PASSWORD is not set or empty"
        validation_failed=1
    fi

    if [ "$validation_failed" = "1" ]; then
        log_error "Required environment variables are missing!"
        log_error "Please check your .env file and ensure all required variables are set:"
        log_error "  - MAAS_URL"
        log_error "  - MAAS_ADMIN_PASSWORD"
        log_error "  - MAAS_ADMIN_EMAIL"
        log_error "  - POSTGRES_PASSWORD"
        exit 1
    fi

    # Display configuration
    log_info "Configuration:"
    log_info "  - MAAS URL: ${MAAS_URL}"
    log_info "  - Admin Username: ${MAAS_ADMIN_USERNAME:-admin}"
    log_info "  - Admin Email: ${MAAS_ADMIN_EMAIL}"
    log_info "  - Database Host: ${POSTGRES_HOST:-postgres}"
    log_info "  - Database Name: ${POSTGRES_DB:-maasdb}"
    log_info "  - Database User: ${POSTGRES_USER:-maas}"
    log_info "  - Debug Mode: ${MAAS_DEBUG:-false}"
    log_info "  - Admin Password: [SET]"

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

    # Import boot images info
    import_boot_images

    log_success "============================================"
    log_success "MAAS Initialization Complete"
    log_success "Web UI: ${MAAS_URL}"
    log_success "Username: ${MAAS_ADMIN_USERNAME:-admin}"
    log_success "Starting systemd to manage MAAS services..."
    log_success "============================================"

    # Enable MAAS services to start with systemd
    log_info "Enabling MAAS services..."
    systemctl enable maas-regiond.service || log_warning "Could not enable maas-regiond service"

    # Create initialization marker to prevent re-initialization on container restart
    local init_marker="/var/lib/maas/.initialized"
    log_info "Creating initialization marker at: $init_marker"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$init_marker"
    chown ${MAAS_UID:-568}:${MAAS_GID:-568} "$init_marker"

    # Exec systemd as PID 1 to manage all services
    # This replaces the current process with systemd
    log_info "Handing control to systemd..."
    exec /sbin/init --log-target=console 3>&1
}

# Run main function
# Note: No signal traps needed - systemd will handle all signal management
main "$@"
