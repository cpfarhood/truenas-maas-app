# Quick Build Guide - Custom MAAS Docker Image

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git
- 50GB+ free disk space
- Internet connection

## Quick Start (5 Steps)

### 1. Verify Files
```bash
cd /Users/cpfarhood/Documents/Repositories/truenas-maas-app

# Check all required files exist
ls -la Dockerfile
ls -la docker/entrypoint.sh
ls -la docker/healthcheck.sh
ls -la compose.yaml
```

### 2. Build the Image
```bash
# Build using Docker Compose
docker compose build maas

# Or build with Docker CLI
docker build -t truenas-maas:3.5 .
```

### 3. Prepare Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env and set required variables:
# - MAAS_URL=http://YOUR_IP:5240/MAAS
# - POSTGRES_PASSWORD=your-secure-password
# - MAAS_ADMIN_PASSWORD=your-admin-password
# - MAAS_ADMIN_EMAIL=admin@example.com

# Create storage directories
sudo mkdir -p /mnt/tank/maas/{config,data,images,logs,tmp,postgres}
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/
```

### 4. Start Services
```bash
# Start all services
docker compose up -d

# Watch logs during first startup (takes 2-5 minutes)
docker compose logs -f maas
```

### 5. Verify Deployment
```bash
# Check container status
docker compose ps

# Check health
docker compose exec maas /usr/local/bin/healthcheck.sh

# Access MAAS UI
# Open browser: http://YOUR_IP:5240/MAAS
# Login with credentials from .env
```

## Build Commands Reference

### Standard Builds
```bash
# Clean build with Docker Compose
docker compose build --no-cache maas

# Build with specific MAAS version
docker compose build --build-arg MAAS_VERSION=3.5 maas

# Build and start in one command
docker compose up -d --build
```

### Development Builds
```bash
# Build with custom UID/GID
docker build \
  --build-arg MAAS_UID=568 \
  --build-arg MAAS_GID=568 \
  -t truenas-maas:dev .

# Build with verbose output
docker compose build --progress=plain maas
```

### Testing Builds
```bash
# Test build without starting
docker compose build maas

# Test with temporary container
docker run --rm -it truenas-maas:3.5 bash

# Inspect image
docker inspect truenas-maas:3.5
docker history truenas-maas:3.5
```

## Validation Tests

### 1. Image Tests
```bash
# Check image size
docker images truenas-maas:3.5

# Verify non-root user
docker run --rm truenas-maas:3.5 id

# Check MAAS version
docker run --rm truenas-maas:3.5 maas --version

# Verify scripts are executable
docker run --rm truenas-maas:3.5 ls -la /usr/local/bin/
```

### 2. Container Tests
```bash
# Start test container
docker compose up -d

# Wait 90 seconds for initialization
sleep 90

# Check container is healthy
docker compose ps | grep healthy

# Test health check
docker compose exec maas /usr/local/bin/healthcheck.sh

# Test API endpoint
docker compose exec maas curl -f http://localhost:5240/MAAS/api/2.0/version/

# Check database connection
docker compose exec maas pg_isready -h postgres -p 5432 -U maas
```

### 3. Permission Tests
```bash
# Verify running as UID 568
docker compose exec maas id

# Check file permissions
docker compose exec maas ls -la /var/lib/maas
docker compose exec maas ls -la /etc/maas
docker compose exec maas ls -la /var/log/maas

# Test write permissions
docker compose exec maas touch /var/lib/maas/test.txt
docker compose exec maas rm /var/lib/maas/test.txt
```

## Troubleshooting

### Build Issues

**Problem**: Build fails with "E: Unable to locate package maas"
```bash
# Solution: Verify MAAS version exists
docker build --build-arg MAAS_VERSION=3.5 -t truenas-maas:3.5 .
```

**Problem**: Build runs out of space
```bash
# Solution: Clean up Docker
docker system prune -a --volumes
docker builder prune -a
```

**Problem**: Scripts not executable
```bash
# Solution: Ensure scripts are executable before build
chmod +x docker/entrypoint.sh docker/healthcheck.sh
docker compose build --no-cache maas
```

### Runtime Issues

**Problem**: Container exits immediately
```bash
# Check logs
docker compose logs maas

# Common fixes:
# 1. Verify .env file has all required variables
# 2. Check PostgreSQL is running: docker compose ps postgres
# 3. Verify volume permissions: ls -la /mnt/tank/maas/
```

**Problem**: Health check fails
```bash
# Debug health check
docker compose exec maas /usr/local/bin/healthcheck.sh

# Check individual components:
docker compose exec maas curl http://localhost:5240/MAAS/api/2.0/version/
docker compose exec maas pg_isready -h postgres
docker compose exec maas pgrep -f maas-regiond
```

**Problem**: Cannot connect to MAAS UI
```bash
# Verify ports are exposed
docker compose ps
netstat -tlnp | grep 5240

# Check firewall
sudo ufw status
sudo ufw allow 5240/tcp

# Test from host
curl http://localhost:5240/MAAS/
```

## Performance Optimization

### Build Performance
```bash
# Use BuildKit for faster builds
DOCKER_BUILDKIT=1 docker build -t truenas-maas:3.5 .

# Enable build cache
docker compose build --build-arg BUILDKIT_INLINE_CACHE=1 maas

# Parallel builds
docker compose build --parallel
```

### Runtime Performance
```bash
# Allocate more memory
docker compose up -d --scale maas=1 \
  --memory=4g --cpus=4

# Use tmpfs for temporary files
docker compose exec maas mount -t tmpfs -o size=1G tmpfs /tmp/maas
```

## Cleanup

### Remove Containers
```bash
# Stop and remove all containers
docker compose down

# Remove with volumes
docker compose down -v
```

### Remove Images
```bash
# Remove built image
docker rmi truenas-maas:3.5

# Remove all unused images
docker image prune -a
```

### Clean Build Cache
```bash
# Clear build cache
docker builder prune -a

# Clear all Docker data
docker system prune -a --volumes
```

## Environment Variables Reference

### Required Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `MAAS_URL` | MAAS web URL | `http://192.168.1.100:5240/MAAS` |
| `MAAS_ADMIN_PASSWORD` | Admin password | `SecurePass123!` |
| `MAAS_ADMIN_EMAIL` | Admin email | `admin@example.com` |
| `POSTGRES_PASSWORD` | Database password | `DbPass456!` |

### Optional Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `MAAS_VERSION` | `3.5` | MAAS version to install |
| `MAAS_ADMIN_USERNAME` | `admin` | Admin username |
| `POSTGRES_HOST` | `postgres` | Database hostname |
| `POSTGRES_PORT` | `5432` | Database port |
| `POSTGRES_DB` | `maasdb` | Database name |
| `POSTGRES_USER` | `maas` | Database user |
| `NETWORK_MODE` | `host` | Network mode (host/bridge) |
| `TZ` | `Etc/UTC` | Timezone |

## Next Steps

After successful build and deployment:

1. **Access MAAS UI**: http://YOUR_IP:5240/MAAS
2. **Login**: Use credentials from .env
3. **Import Boot Images**: Settings > Images > Ubuntu > Import
4. **Configure Networking**: Subnets > Add VLAN/Subnet
5. **Enable DHCP**: Subnet > Enable DHCP
6. **Add Machines**: Machines > Add Machine

## Support

- **Documentation**: See `docker/README.md` for detailed information
- **Implementation Details**: See `DOCKER-BUILD-IMPLEMENTATION.md`
- **Compose Configuration**: See `compose.yaml` comments
- **Issues**: Check logs with `docker compose logs -f`

## Quick Commands Cheat Sheet

```bash
# Build and start
docker compose up -d --build

# View logs
docker compose logs -f maas

# Check status
docker compose ps

# Run health check
docker compose exec maas /usr/local/bin/healthcheck.sh

# Restart service
docker compose restart maas

# Stop all
docker compose down

# Complete reset
docker compose down -v && \
  rm -rf /mnt/tank/maas/* && \
  docker compose up -d --build
```

---

**Version**: 1.0.0
**Last Updated**: February 12, 2026
