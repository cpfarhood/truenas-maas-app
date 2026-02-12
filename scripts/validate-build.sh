#!/bin/bash
# TrueNAS MAAS Application - Build Validation Script
# Version: 1.0.0
# Tests the custom Docker build for TrueNAS compliance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test 1: Check required files exist
test_files_exist() {
    log_test "Checking required files exist..."

    local files=(
        "Dockerfile"
        "docker/entrypoint.sh"
        "docker/healthcheck.sh"
        "docker/README.md"
        ".dockerignore"
        "compose.yaml"
    )

    local all_exist=true
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_info "  ✓ $file exists"
        else
            log_info "  ✗ $file missing"
            all_exist=false
        fi
    done

    if $all_exist; then
        log_pass "All required files exist"
    else
        log_fail "Some files are missing"
    fi
}

# Test 2: Check script permissions
test_script_permissions() {
    log_test "Checking script permissions..."

    if [ -x "docker/entrypoint.sh" ] && [ -x "docker/healthcheck.sh" ]; then
        log_pass "Scripts are executable"
    else
        log_fail "Scripts are not executable"
        log_info "  Run: chmod +x docker/entrypoint.sh docker/healthcheck.sh"
    fi
}

# Test 3: Validate Dockerfile
test_dockerfile() {
    log_test "Validating Dockerfile..."

    local checks=0
    local passed=0

    # Check for non-root user
    if grep -q "USER \${MAAS_UID}:\${MAAS_GID}" Dockerfile; then
        log_info "  ✓ Non-root user configured"
        passed=$((passed + 1))
    else
        log_info "  ✗ Non-root user not found"
    fi
    checks=$((checks + 1))

    # Check for health check
    if grep -q "HEALTHCHECK" Dockerfile; then
        log_info "  ✓ Healthcheck configured"
        passed=$((passed + 1))
    else
        log_info "  ✗ Healthcheck not found"
    fi
    checks=$((checks + 1))

    # Check for MAAS installation
    if grep -q "maas-region-api" Dockerfile || grep -q "add-apt-repository.*maas" Dockerfile; then
        log_info "  ✓ MAAS installation present"
        passed=$((passed + 1))
    else
        log_info "  ✗ MAAS installation not found"
    fi
    checks=$((checks + 1))

    # Check for entrypoint
    if grep -q "ENTRYPOINT.*entrypoint.sh" Dockerfile; then
        log_info "  ✓ Entrypoint configured"
        passed=$((passed + 1))
    else
        log_info "  ✗ Entrypoint not found"
    fi
    checks=$((checks + 1))

    if [ $passed -eq $checks ]; then
        log_pass "Dockerfile validation passed ($passed/$checks checks)"
    else
        log_fail "Dockerfile validation failed ($passed/$checks checks)"
    fi
}

# Test 4: Validate compose.yaml
test_compose_yaml() {
    log_test "Validating compose.yaml..."

    local checks=0
    local passed=0

    # Check for build configuration
    if grep -q "build:" compose.yaml; then
        log_info "  ✓ Build configuration present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Build configuration not found"
    fi
    checks=$((checks + 1))

    # Check for Dockerfile reference
    if grep -q "dockerfile: Dockerfile" compose.yaml; then
        log_info "  ✓ Dockerfile reference present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Dockerfile reference not found"
    fi
    checks=$((checks + 1))

    # Check for non-root user
    if grep -q 'user: "1000:1000"' compose.yaml; then
        log_info "  ✓ Non-root user configured"
        passed=$((passed + 1))
    else
        log_info "  ✗ Non-root user not found"
    fi
    checks=$((checks + 1))

    # Check for health check
    if grep -q "healthcheck:" compose.yaml; then
        log_info "  ✓ Healthcheck configured"
        passed=$((passed + 1))
    else
        log_info "  ✗ Healthcheck not found"
    fi
    checks=$((checks + 1))

    if [ $passed -eq $checks ]; then
        log_pass "compose.yaml validation passed ($passed/$checks checks)"
    else
        log_fail "compose.yaml validation failed ($passed/$checks checks)"
    fi
}

# Test 5: Check Docker availability
test_docker_available() {
    log_test "Checking Docker availability..."

    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version)
        log_pass "Docker is available: $version"
    else
        log_fail "Docker is not available"
        log_info "  Please install Docker"
    fi
}

# Test 6: Check Docker Compose availability
test_compose_available() {
    log_test "Checking Docker Compose availability..."

    if docker compose version >/dev/null 2>&1; then
        local version=$(docker compose version)
        log_pass "Docker Compose is available: $version"
    else
        log_fail "Docker Compose is not available"
        log_info "  Please install Docker Compose v2"
    fi
}

# Test 7: Validate entrypoint script
test_entrypoint_script() {
    log_test "Validating entrypoint script..."

    local checks=0
    local passed=0

    # Check for PostgreSQL wait
    if grep -q "wait_for_postgres" docker/entrypoint.sh; then
        log_info "  ✓ PostgreSQL wait function present"
        passed=$((passed + 1))
    else
        log_info "  ✗ PostgreSQL wait function not found"
    fi
    checks=$((checks + 1))

    # Check for database initialization
    if grep -q "initialize_database" docker/entrypoint.sh; then
        log_info "  ✓ Database initialization present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Database initialization not found"
    fi
    checks=$((checks + 1))

    # Check for admin user creation
    if grep -q "create_admin_user" docker/entrypoint.sh; then
        log_info "  ✓ Admin user creation present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Admin user creation not found"
    fi
    checks=$((checks + 1))

    # Check for signal handling
    if grep -q "trap" docker/entrypoint.sh; then
        log_info "  ✓ Signal handling present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Signal handling not found"
    fi
    checks=$((checks + 1))

    if [ $passed -eq $checks ]; then
        log_pass "Entrypoint script validation passed ($passed/$checks checks)"
    else
        log_fail "Entrypoint script validation failed ($passed/$checks checks)"
    fi
}

# Test 8: Validate healthcheck script
test_healthcheck_script() {
    log_test "Validating healthcheck script..."

    local checks=0
    local passed=0

    # Check for API check
    if grep -q "check_maas_api" docker/healthcheck.sh; then
        log_info "  ✓ API check function present"
        passed=$((passed + 1))
    else
        log_info "  ✗ API check function not found"
    fi
    checks=$((checks + 1))

    # Check for database check
    if grep -q "check_database" docker/healthcheck.sh; then
        log_info "  ✓ Database check function present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Database check function not found"
    fi
    checks=$((checks + 1))

    # Check for process check
    if grep -q "check_maas_process" docker/healthcheck.sh; then
        log_info "  ✓ Process check function present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Process check function not found"
    fi
    checks=$((checks + 1))

    # Check for directory check
    if grep -q "check_directories" docker/healthcheck.sh; then
        log_info "  ✓ Directory check function present"
        passed=$((passed + 1))
    else
        log_info "  ✗ Directory check function not found"
    fi
    checks=$((checks + 1))

    if [ $passed -eq $checks ]; then
        log_pass "Healthcheck script validation passed ($passed/$checks checks)"
    else
        log_fail "Healthcheck script validation failed ($passed/$checks checks)"
    fi
}

# Test 9: Try build (optional)
test_build() {
    if [ "$SKIP_BUILD" = "true" ]; then
        log_info "Skipping build test (SKIP_BUILD=true)"
        return
    fi

    log_test "Testing Docker build..."

    if docker compose build maas >/dev/null 2>&1; then
        log_pass "Docker build successful"
    else
        log_fail "Docker build failed"
        log_info "  Run 'docker compose build maas' for details"
    fi
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "TrueNAS MAAS Build Validation"
    echo "=========================================="
    echo ""

    # Run tests
    test_files_exist
    test_script_permissions
    test_dockerfile
    test_compose_yaml
    test_docker_available
    test_compose_available
    test_entrypoint_script
    test_healthcheck_script
    test_build

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Create .env file with required variables"
        echo "2. Run: docker compose up -d --build"
        echo "3. Monitor: docker compose logs -f maas"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo "Please fix the issues above before building."
        exit 1
    fi
}

# Run main
main "$@"
