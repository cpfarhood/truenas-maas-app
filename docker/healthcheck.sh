#!/bin/bash
# TrueNAS MAAS Application - Health Check Script
# Version: 1.0.0
# Validates MAAS API availability and database connectivity

set -e

# Health check timeout
TIMEOUT=5

# Exit codes
EXIT_SUCCESS=0
EXIT_FAILURE=1

# Function to check MAAS API availability
check_maas_api() {
    local api_url="http://localhost:5240/MAAS/api/2.0/version/"

    # Try to reach MAAS API endpoint
    if curl -sf --max-time ${TIMEOUT} "${api_url}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check database connectivity
check_database() {
    # Check if PostgreSQL is reachable and MAAS can connect
    if pg_isready -h "${POSTGRES_HOST:-postgres}" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-maas}" -t ${TIMEOUT} > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if MAAS region controller is running
check_maas_process() {
    # Check if MAAS region controller processes are running
    if pgrep -f "maas-regiond" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check critical directories
check_directories() {
    local directories=(
        "/etc/maas"
        "/var/lib/maas"
        "/var/log/maas"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "${dir}" ] || [ ! -w "${dir}" ]; then
            echo "ERROR: Directory ${dir} is not accessible or writable"
            return 1
        fi
    done

    return 0
}

# Main health check function
main() {
    local errors=0
    local warnings=0

    # Check 1: Critical directories
    if ! check_directories; then
        echo "FAILED: Critical directories check"
        errors=$((errors + 1))
    fi

    # Check 2: Database connectivity
    if ! check_database; then
        echo "FAILED: Database connectivity check"
        errors=$((errors + 1))
    fi

    # Check 3: MAAS process running
    if ! check_maas_process; then
        echo "WARNING: MAAS region controller process not detected"
        warnings=$((warnings + 1))
        # Don't fail immediately, process might be restarting
    fi

    # Check 4: MAAS API availability (most important)
    if ! check_maas_api; then
        echo "FAILED: MAAS API is not responding"
        errors=$((errors + 1))
    fi

    # Determine overall health
    if [ ${errors} -gt 0 ]; then
        echo "UNHEALTHY: ${errors} critical checks failed, ${warnings} warnings"
        return ${EXIT_FAILURE}
    fi

    if [ ${warnings} -gt 0 ]; then
        echo "DEGRADED: ${warnings} warnings detected, but service is operational"
    else
        echo "HEALTHY: All checks passed"
    fi

    return ${EXIT_SUCCESS}
}

# Run health check
main "$@"
exit $?
