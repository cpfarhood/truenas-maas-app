#!/bin/bash
# validate-compose.sh
# Validates Docker Compose configuration and checks prerequisites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
ENV_FILE="${PROJECT_ROOT}/.env"

echo "=========================================="
echo "MAAS Docker Compose Validation Script"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
echo "[1/8] Checking Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} Docker found: ${DOCKER_VERSION}"
else
    echo -e "${RED}✗${NC} Docker not found. Please install Docker."
    exit 1
fi

# Check if Docker Compose is available
echo "[2/8] Checking Docker Compose availability..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✓${NC} Docker Compose found: ${COMPOSE_VERSION}"
else
    echo -e "${RED}✗${NC} Docker Compose not available."
    exit 1
fi

# Check if compose.yaml exists
echo "[3/8] Checking compose.yaml file..."
if [ -f "$COMPOSE_FILE" ]; then
    echo -e "${GREEN}✓${NC} compose.yaml found"
else
    echo -e "${RED}✗${NC} compose.yaml not found at: $COMPOSE_FILE"
    exit 1
fi

# Check if .env file exists
echo "[4/8] Checking environment configuration..."
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✓${NC} .env file found"

    # Check for required variables
    REQUIRED_VARS=(
        "MAAS_URL"
        "MAAS_ADMIN_PASSWORD"
        "MAAS_ADMIN_EMAIL"
        "POSTGRES_PASSWORD"
    )

    MISSING_VARS=()
    for var in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^${var}=" "$ENV_FILE"; then
            MISSING_VARS+=("$var")
        fi
    done

    if [ ${#MISSING_VARS[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All required variables present"
    else
        echo -e "${YELLOW}⚠${NC} Missing required variables:"
        for var in "${MISSING_VARS[@]}"; do
            echo "  - $var"
        done
    fi
else
    echo -e "${YELLOW}⚠${NC} .env file not found (optional for validation)"
    echo "  Copy .env.example to .env and configure before deployment"
fi

# Validate compose.yaml syntax
echo "[5/8] Validating Docker Compose syntax..."
cd "$PROJECT_ROOT"
if docker compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Compose syntax is valid"
else
    echo -e "${RED}✗${NC} Docker Compose syntax validation failed:"
    docker compose config 2>&1 | head -20
    exit 1
fi

# Check storage paths
echo "[6/8] Checking storage paths..."
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"

    STORAGE_PATHS=(
        "${MAAS_CONFIG_PATH:-/mnt/tank/maas/config}"
        "${MAAS_DATA_PATH:-/mnt/tank/maas/data}"
        "${MAAS_IMAGES_PATH:-/mnt/tank/maas/images}"
        "${MAAS_LOGS_PATH:-/mnt/tank/maas/logs}"
        "${MAAS_TMP_PATH:-/mnt/tank/maas/tmp}"
        "${POSTGRES_DATA_PATH:-/mnt/tank/maas/postgres}"
    )

    MISSING_PATHS=()
    WRONG_PERMISSIONS=()

    for path in "${STORAGE_PATHS[@]}"; do
        if [ ! -d "$path" ]; then
            MISSING_PATHS+=("$path")
        else
            # Check ownership (should be 1000:1000)
            OWNER=$(stat -c '%u:%g' "$path" 2>/dev/null || stat -f '%u:%g' "$path" 2>/dev/null || echo "unknown")
            if [ "$OWNER" != "1000:1000" ] && [ "$OWNER" != "unknown" ]; then
                WRONG_PERMISSIONS+=("$path (owner: $OWNER, should be 1000:1000)")
            fi
        fi
    done

    if [ ${#MISSING_PATHS[@]} -eq 0 ] && [ ${#WRONG_PERMISSIONS[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All storage paths exist with correct permissions"
    else
        if [ ${#MISSING_PATHS[@]} -gt 0 ]; then
            echo -e "${YELLOW}⚠${NC} Missing storage paths:"
            for path in "${MISSING_PATHS[@]}"; do
                echo "  - $path"
            done
            echo ""
            echo "Create with:"
            echo "  sudo mkdir -p ${STORAGE_PATHS[@]}"
            echo "  sudo chown -R 1000:1000 /mnt/tank/maas/"
        fi

        if [ ${#WRONG_PERMISSIONS[@]} -gt 0 ]; then
            echo -e "${YELLOW}⚠${NC} Incorrect permissions on paths:"
            for path in "${WRONG_PERMISSIONS[@]}"; do
                echo "  - $path"
            done
            echo ""
            echo "Fix with:"
            echo "  sudo chown -R 1000:1000 /mnt/tank/maas/"
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot check storage paths without .env file"
fi

# Check available disk space
echo "[7/8] Checking available disk space..."
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    BASE_PATH=$(dirname "${MAAS_CONFIG_PATH:-/mnt/tank/maas/config}")

    if [ -d "$BASE_PATH" ]; then
        AVAILABLE=$(df -BG "$BASE_PATH" | tail -1 | awk '{print $4}' | sed 's/G//')
        REQUIRED=135

        if [ "$AVAILABLE" -ge "$REQUIRED" ]; then
            echo -e "${GREEN}✓${NC} Sufficient disk space: ${AVAILABLE}GB available (${REQUIRED}GB required)"
        else
            echo -e "${YELLOW}⚠${NC} Low disk space: ${AVAILABLE}GB available (${REQUIRED}GB recommended)"
            echo "  Consider allocating more space for boot images"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Cannot check disk space - base path does not exist: $BASE_PATH"
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot check disk space without .env file"
fi

# Check port availability
echo "[8/8] Checking port availability..."
PORTS_TO_CHECK=("5240" "5443" "69")
PORTS_IN_USE=()

for port in "${PORTS_TO_CHECK[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || lsof -i ":${port}" &>/dev/null; then
        PORTS_IN_USE+=("$port")
    fi
done

if [ ${#PORTS_IN_USE[@]} -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Required ports are available"
else
    echo -e "${YELLOW}⚠${NC} Ports already in use (may conflict in bridge mode):"
    for port in "${PORTS_IN_USE[@]}"; do
        echo "  - Port $port"
    done
    echo ""
    echo "Note: This is only a concern if using bridge network mode."
    echo "      Host network mode will use ports directly on the host."
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""

# Count issues
TOTAL_CHECKS=8
ISSUES=0

if ! command -v docker &> /dev/null; then ((ISSUES++)); fi
if ! docker compose version &> /dev/null; then ((ISSUES++)); fi
if [ ! -f "$COMPOSE_FILE" ]; then ((ISSUES++)); fi
if [ ${#MISSING_VARS[@]} -gt 0 ]; then ((ISSUES++)); fi
if ! docker compose config > /dev/null 2>&1; then ((ISSUES++)); fi
if [ ${#MISSING_PATHS[@]} -gt 0 ] || [ ${#WRONG_PERMISSIONS[@]} -gt 0 ]; then ((ISSUES++)); fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo "You can now deploy MAAS with:"
    echo "  docker compose up -d"
    exit 0
else
    echo -e "${YELLOW}⚠ Found $ISSUES issue(s) that should be addressed${NC}"
    echo ""
    echo "Please resolve the issues above before deploying."
    exit 1
fi
