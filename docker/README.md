# MAAS Custom Docker Image

This directory contains the custom Docker image configuration for MAAS (Metal as a Service) optimized for TrueNAS 25.10+.

## Overview

The custom Docker image provides:
- **Non-root operation**: Runs as user/group 568:568 (TrueNAS 25.10+ requirement)
- **Ubuntu 22.04 base**: Official MAAS recommended base image
- **MAAS 3.5**: Latest stable version from official PPA
- **Health checks**: Comprehensive health monitoring for container orchestration
- **Proper permissions**: All directories configured for non-root access
- **Optimized startup**: Intelligent initialization and database migration handling

## Image Details

### Base Configuration
- **Base Image**: Ubuntu 22.04 LTS
- **MAAS Version**: 3.5 (from official PPA)
- **User/Group**: maas (UID 568, GID 568)
- **Default Shell**: bash

### Installed Components
- MAAS region controller
- MAAS region API
- PostgreSQL client
- DHCP server (maas-dhcp)
- DNS server (bind9)
- HTTP proxy (squid)
- Nginx web server
- Network utilities (iproute2, netcat, dnsutils)

### Exposed Ports
| Port | Protocol | Service |
|------|----------|---------|
| 5240 | TCP | HTTP UI/API |
| 5443 | TCP | HTTPS UI/API |
| 69 | UDP | TFTP (PXE boot) |
| 5241-5248 | TCP | Region controller services |
| 5250-5270 | TCP | Rack controller services |
| 8000 | TCP | HTTP proxy |

### Volume Mount Points
- `/etc/maas` - Configuration files
- `/var/lib/maas` - Application data
- `/var/log/maas` - Log files
- `/tmp/maas` - Temporary files

## Building the Image

### Prerequisites
- Docker 20.10 or newer
- Docker Compose 2.0 or newer (for compose.yaml)

### Build Commands

#### Using Docker Compose (Recommended)
```bash
# Build the image
docker compose build maas

# Build with no cache (clean build)
docker compose build --no-cache maas

# Build with custom build args
docker compose build --build-arg MAAS_VERSION=3.5 maas
```

#### Using Docker CLI
```bash
# Basic build
docker build -t truenas-maas:3.5 .

# Build with custom UID/GID
docker build \
  --build-arg MAAS_UID=1000 \
  --build-arg MAAS_GID=1000 \
  -t truenas-maas:3.5 .

# Build with specific MAAS version
docker build \
  --build-arg MAAS_VERSION=3.5 \
  -t truenas-maas:3.5 .
```

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `MAAS_VERSION` | 3.5 | MAAS version to install |
| `MAAS_UID` | 1000 | User ID for maas user |
| `MAAS_GID` | 1000 | Group ID for maas group |
| `DEBIAN_FRONTEND` | noninteractive | Debian package installation mode |

## Scripts

### entrypoint.sh
The entrypoint script handles container initialization:

**Features:**
- Waits for PostgreSQL to be ready (30 attempts, 2s interval)
- Checks if database is initialized
- Runs database migrations on first start
- Creates admin user if needed
- Configures MAAS settings
- Starts MAAS region controller
- Monitors service health

**Environment Variables:**
- `POSTGRES_HOST` - Database host (default: postgres)
- `POSTGRES_PORT` - Database port (default: 5432)
- `POSTGRES_DB` - Database name (default: maasdb)
- `POSTGRES_USER` - Database user (default: maas)
- `POSTGRES_PASSWORD` - Database password (required)
- `MAAS_URL` - MAAS URL (required)
- `MAAS_ADMIN_USERNAME` - Admin username (default: admin)
- `MAAS_ADMIN_PASSWORD` - Admin password (required)
- `MAAS_ADMIN_EMAIL` - Admin email (required)
- `MAAS_REGION_SECRET` - Region secret (optional)
- `MAAS_DNS_FORWARDER` - DNS forwarder (default: 8.8.8.8)
- `MAAS_BOOT_IMAGES_AUTO_IMPORT` - Auto-import boot images (default: true)
- `MAAS_DEBUG` - Debug mode (default: false)

### healthcheck.sh
The health check script validates container health:

**Checks:**
1. Critical directories are accessible and writable
2. PostgreSQL database connectivity
3. MAAS region controller process is running
4. MAAS API endpoint responds

**Exit Codes:**
- `0` - Healthy: All checks passed
- `1` - Unhealthy: One or more critical checks failed

**Timing:**
- Interval: 30 seconds
- Timeout: 10 seconds
- Start period: 90 seconds
- Retries: 3

## Usage

### Quick Start with Docker Compose
```bash
# Create .env file with required variables
cat > .env <<EOF
MAAS_URL=http://192.168.1.100:5240/MAAS
MAAS_ADMIN_PASSWORD=your-secure-password
MAAS_ADMIN_EMAIL=admin@example.com
POSTGRES_PASSWORD=your-database-password
EOF

# Start services
docker compose up -d

# View logs
docker compose logs -f maas

# Check health
docker compose ps
```

### Running Standalone
```bash
# Create network
docker network create maas-internal

# Start PostgreSQL
docker run -d \
  --name maas-postgres \
  --network maas-internal \
  -e POSTGRES_DB=maasdb \
  -e POSTGRES_USER=maas \
  -e POSTGRES_PASSWORD=secure-password \
  -v /mnt/tank/maas/postgres:/var/lib/postgresql/data \
  postgres:15-alpine

# Start MAAS
docker run -d \
  --name maas-region \
  --network maas-internal \
  --network host \
  -e MAAS_URL=http://192.168.1.100:5240/MAAS \
  -e MAAS_ADMIN_USERNAME=admin \
  -e MAAS_ADMIN_PASSWORD=secure-password \
  -e MAAS_ADMIN_EMAIL=admin@example.com \
  -e POSTGRES_HOST=maas-postgres \
  -e POSTGRES_PASSWORD=secure-password \
  -v /mnt/tank/maas/config:/etc/maas \
  -v /mnt/tank/maas/data:/var/lib/maas \
  -v /mnt/tank/maas/logs:/var/log/maas \
  truenas-maas:3.5
```

## Customization

### Changing User ID/Group ID
If you need to use a different UID/GID:

```bash
# Build with custom UID/GID
docker build \
  --build-arg MAAS_UID=568 \
  --build-arg MAAS_GID=568 \
  -t truenas-maas:3.5-custom .

# Update compose.yaml
services:
  maas:
    build:
      context: .
      args:
        MAAS_UID: 568
        MAAS_GID: 568
    user: "568:568"
```

### Adding Custom Packages
Edit the Dockerfile to add additional packages:

```dockerfile
# Add custom packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    your-package-name \
    && rm -rf /var/lib/apt/lists/*
```

### Custom Configuration Files
Mount custom configuration files:

```yaml
volumes:
  - ./custom-config.yaml:/etc/maas/custom-config.yaml:ro
```

### Environment-Specific Builds
Create environment-specific Dockerfiles:

```bash
# Development build with debug tools
docker build \
  -f Dockerfile.dev \
  -t truenas-maas:dev .

# Production build (minimal)
docker build \
  -f Dockerfile.prod \
  -t truenas-maas:prod .
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker compose logs maas

# Common issues:
# 1. Database not ready - Wait 30-60 seconds
# 2. Wrong permissions - Check volume ownership
# 3. Port conflicts - Check if ports are in use
```

### Permission Denied Errors
```bash
# Fix volume permissions
sudo chown -R 568:568 /mnt/tank/maas/
sudo chmod -R 755 /mnt/tank/maas/
```

### Database Connection Failed
```bash
# Check PostgreSQL is running
docker compose ps postgres

# Test connection
docker compose exec maas pg_isready -h postgres -p 5432 -U maas

# View database logs
docker compose logs postgres
```

### Health Check Failing
```bash
# Run health check manually
docker compose exec maas /usr/local/bin/healthcheck.sh

# Check specific components
docker compose exec maas curl -f http://localhost:5240/MAAS/api/2.0/version/
docker compose exec maas pg_isready -h postgres -p 5432 -U maas
```

### Build Failures
```bash
# Clean build with no cache
docker compose build --no-cache maas

# Check disk space
df -h

# Remove old images
docker image prune -a
```

## Security Considerations

### Non-Root Operation
The image runs as non-root user (UID 568) by default. This is a TrueNAS 25.10+ requirement for enhanced security.

### Capabilities
Required Linux capabilities:
- `NET_ADMIN` - Network configuration (DHCP, DNS)
- `NET_RAW` - Raw socket access (DHCP server)
- `NET_BIND_SERVICE` - Bind to privileged ports

### Secrets Management
Never hardcode secrets in the Dockerfile. Use:
- Environment variables
- Docker secrets
- Mounted configuration files

### Updates
Regularly update the base image and MAAS:

```bash
# Rebuild with latest packages
docker compose build --no-cache --pull maas
```

## Performance Optimization

### Image Size
Current image size: ~800MB

Optimization tips:
- Use multi-stage builds for development
- Minimize installed packages
- Clean up apt cache
- Use alpine-based images where possible

### Build Cache
Leverage Docker build cache:
- Order Dockerfile commands from least to most frequently changed
- Use `.dockerignore` to exclude unnecessary files
- Pin package versions for reproducible builds

### Runtime Performance
- Use volumes for persistent data (not bind mounts)
- Allocate sufficient memory (4GB minimum)
- Use host networking for PXE boot performance

## Development

### Local Testing
```bash
# Build development image
docker build -t truenas-maas:dev --target development .

# Run with development overrides
docker compose -f compose.yaml -f compose.dev.yaml up
```

### Debugging
```bash
# Start with shell
docker compose run --rm maas bash

# View running processes
docker compose exec maas ps aux

# Check file permissions
docker compose exec maas ls -la /var/lib/maas
```

## References

- [MAAS Documentation](https://maas.io/docs)
- [Docker Documentation](https://docs.docker.com/)
- [TrueNAS Apps Documentation](https://www.truenas.com/docs/truenasapps/)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)

## Support

For issues and questions:
- GitHub Issues: [Repository Issues](https://github.com/yourusername/truenas-maas-app/issues)
- MAAS Discourse: [https://discourse.maas.io/](https://discourse.maas.io/)
- TrueNAS Forums: [https://forums.truenas.com/](https://forums.truenas.com/)

## License

This project is provided as-is for use with TrueNAS SCALE applications.
