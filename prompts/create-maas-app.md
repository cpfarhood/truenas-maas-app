# Build a MAAS Integration App for TrueNAS

## Target Version

**TrueNAS 25.10 and Later**

This prompt is specifically designed for TrueNAS 25.10 (Goldeye) and later versions. Applications built using these instructions will leverage the modern JSON-RPC 2.0 WebSocket API and Docker Compose infrastructure introduced in TrueNAS 25.x.

**Important Version Notes:**
- **Minimum Version**: TrueNAS 25.10.0
- **API**: JSON-RPC 2.0 over WebSocket (REST API deprecated in 25.04, removed in 26.04)
- **Container Runtime**: Docker Compose (native support since 24.10)
- **Breaking Changes**: See "Version Compatibility" section for migration considerations

## Executive Summary

Create a production-ready TrueNAS application that integrates with MAAS (Metal as a Service) to enable bare metal server provisioning and lifecycle management directly from the TrueNAS interface. This application will provide a web-based UI and API for managing physical infrastructure through MAAS, streamlining workflows for data center automation, edge computing deployments, and Kubernetes cluster provisioning.

## Background Context

### What is MAAS?

MAAS (Metal as a Service) is Canonical's bare metal provisioning system that treats physical servers like virtual machines in the cloud. Key capabilities include:

- **Automated Discovery**: Automatically discovers physical machines on the network via PXE boot
- **OS Provisioning**: Deploys operating systems (Ubuntu, CentOS, RHEL, Windows, etc.) to bare metal in under 2 minutes
- **Lifecycle Management**: Commissioning, deployment, power management, and decommissioning workflows
- **Storage Configuration**: Automated RAID, LVM, ZFS, and bcache configuration
- **Network Management**: DHCP, DNS, VLAN, and subnet management
- **API-First Design**: RESTful API with OAuth authentication for full automation
- **DevOps Integration**: Native integration with Terraform, Ansible, Juju, and Kubernetes

**Primary Use Cases:**
- Private cloud infrastructure provisioning (OpenStack, Kubernetes)
- High-performance computing (HPC) cluster deployment
- Edge computing with remote bare metal management
- Continuous integration/deployment infrastructure
- Rapid hardware repurposing and testing environments

**Sources:**
- [MAAS Documentation](https://canonical.com/maas)
- [MAAS API Reference](https://canonical.com/maas/docs/api)
- [MAAS Use Cases](https://phoenixnap.com/blog/automated-server-provisioning-bare-metal-cloud)

### What is TrueNAS?

TrueNAS is an enterprise-grade open-source network-attached storage (NAS) operating system built on OpenZFS. As of version 25.10 (Goldeye), TrueNAS provides mature Docker Compose support for container orchestration with a modern JSON-RPC API.

**Key Architecture for TrueNAS 25.10+:**
- **Container Runtime**: Docker Compose with native TrueNAS integration
- **API**: JSON-RPC 2.0 over WebSocket (primary API interface)
  - REST API deprecated in 25.04, removed in 26.04
  - Daily alerts for deprecated endpoint usage (25.10.1+)
  - Migration to WebSocket API required before 26.04
- **App Deployment**: Docker images with compose.yaml definitions
- **Catalog Structure**: Organized by "trains" (stable, community, enterprise, test)
- **Registry Mirrors**: Support for external container registry mirrors (25.10+)
- **Service Timeout**: Extended to 960 seconds for slower disk scenarios (25.10+)

**Version Compatibility:**
- **25.10+**: All features supported, REST API deprecated with alerts
- **26.04+**: REST API removed, JSON-RPC 2.0 WebSocket only
- **24.10**: Not recommended (lacks 25.10+ improvements and API warnings)

**Sources:**
- [TrueNAS 25.10 Version Notes](https://www.truenas.com/docs/scale/25.10/gettingstarted/versionnotes/)
- [TrueNAS API Reference](https://www.truenas.com/docs/scale/25.10/api/)
- [TrueNAS Apps Documentation](https://www.truenas.com/docs/truenasapps/)
- [TrueNAS Apps Repository](https://github.com/truenas/apps)
- [26.04 Development Notes](https://www.truenas.com/docs/scale/gettingstarted/versionnotes/)
- [Feature Deprecations](https://www.truenas.com/docs/scale/gettingstarted/deprecations/)

### Why Integrate MAAS with TrueNAS?

This integration provides several strategic benefits:

1. **Unified Infrastructure Management**: Manage both storage (TrueNAS) and compute (MAAS) from a single platform
2. **Automated Workflows**: Provision bare metal servers that automatically mount TrueNAS storage
3. **Edge Deployment**: Deploy and manage remote bare metal nodes with centralized storage
4. **Container/VM Infrastructure**: Provision Kubernetes nodes or hypervisor hosts with integrated storage
5. **Disaster Recovery**: Rapidly reprovision failed hardware with predefined configurations
6. **DevOps Enablement**: Infrastructure-as-code workflows combining storage and compute provisioning

## Version Compatibility and Migration

### TrueNAS 25.10+ Requirements

This app is designed specifically for TrueNAS 25.10 (Goldeye) and later versions. The following features and changes are relevant:

**API Requirements:**
- **JSON-RPC 2.0 WebSocket API**: Primary API interface for TrueNAS integration
  - Endpoint: `ws://truenas-host/websocket`
  - Authentication: API keys or session tokens
  - Full API reference: [TrueNAS API v25.10](https://api.truenas.com/v25.04/jsonrpc.html)
- **REST API Status**:
  - Deprecated in 25.04
  - Daily alerts for usage in 25.10.1+
  - **Will be removed in 26.04**
  - Do NOT use REST API in new applications

**Docker Compose Features (25.10+):**
- Native Docker Compose support with TrueNAS extensions
- Container registry mirror support
- Extended service timeout (960 seconds) for slower storage
- Custom app validation improvements
- Version tracking for image updates

**Breaking Changes from 24.10:**
1. **API Keys**: Legacy API keys from 24.10 or earlier migrate to root/admin/truenas_admin accounts
2. **API Method Allow Lists**: Existing API keys with allow lists are revoked on upgrade
3. **IDMAP Backend**: AUTORID removed, migrated to RID automatically
4. **GPU Support**: Legacy NVIDIA GPUs (Pascal, Maxwell, Volta) no longer supported

### Migration from 24.10 to 25.10+

If upgrading from TrueNAS 24.10:

1. **API Integration Updates** (if applicable):
   - Replace any REST API calls with JSON-RPC 2.0 WebSocket
   - Regenerate API keys after upgrade
   - Update authentication methods

2. **Docker Compose Changes**:
   - Add `services:` key to custom YAML for new stacks
   - Update existing stacks to new YAML format
   - Verify volume mount paths remain consistent

3. **Testing Requirements**:
   - Test app installation on fresh 25.10 instance
   - Verify no REST API deprecation warnings
   - Confirm all features work with JSON-RPC API

**Recommended Upgrade Path:**
- If on 24.10: Upgrade to 25.04 → 25.10 (preferred path)
- Direct upgrade from 24.10 to 25.10 is supported but test thoroughly

**Sources:**
- [25.04 Version Notes](https://www.truenas.com/docs/scale/25.04/gettingstarted/scalereleasenotes/)
- [25.10 Version Notes](https://www.truenas.com/docs/scale/25.10/gettingstarted/versionnotes/)
- [26.04 Development Notes](https://www.truenas.com/docs/scale/gettingstarted/versionnotes/)
- [Feature Deprecations](https://www.truenas.com/docs/scale/gettingstarted/deprecations/)

## Technical Requirements

### TrueNAS App Structure

Your app must follow the TrueNAS app catalog structure with these components:

#### 1. App Metadata (`app.yaml`)

Located at `ix-dev/<train>/<app-name>/app.yaml`, this file defines the app's metadata:

```yaml
# Required fields
name: maas                                    # Unique app identifier (lowercase, no spaces)
title: MAAS - Metal as a Service             # Display name in UI
version: 1.0.0                                # App package version (semantic versioning)
app_version: 3.5.0                            # MAAS software version
train: community                              # Train: stable, community, enterprise, test
lib_version: 2.1.77                           # TrueNAS app library version
lib_version_hash: <hash>                      # Library version hash for validation

# Descriptive fields
description: |
  MAAS (Metal as a Service) provides automated bare metal server provisioning,
  lifecycle management, and infrastructure orchestration. Deploy operating systems,
  configure storage, manage networking, and control physical infrastructure through
  a modern web UI and RESTful API.

home: https://maas.io                         # Project homepage
changelog_url: https://discourse.maas.io      # Changelog location

# Categorization
categories:
  - infrastructure
  - automation
  - cloud
keywords:
  - maas
  - bare-metal
  - provisioning
  - infrastructure
  - automation
  - pxe
  - ipmi
  - bmc

# Version requirements
min_scale_version: 25.10.0                    # Minimum TrueNAS version (25.10+)

# Security context
run_as_context:
  - description: MAAS runs as a dedicated user for security isolation
    uid: 1000                                 # Non-root user ID
    gid: 1000                                 # Non-root group ID
    user_name: maas                           # Username
    group_name: maas                          # Group name

# Visual assets
icon: https://media.sys.truenas.net/apps/maas/icons/icon.png
screenshots:
  - https://media.sys.truenas.net/apps/maas/screenshots/dashboard.png
  - https://media.sys.truenas.net/apps/maas/screenshots/machines.png

# Maintainer information
maintainers:
  - name: Your Name
    email: your.email@example.com
    url: https://github.com/yourusername

# Source references
sources:
  - https://github.com/canonical/maas
  - https://github.com/yourusername/truenas-maas-app

# Host requirements (if any special mounts needed)
host_mounts: []

# Capabilities required (Linux capabilities)
capabilities:
  - NET_ADMIN                                 # Network configuration
  - NET_RAW                                   # Raw socket access for DHCP
  - SYS_ADMIN                                 # System administration
```

**Key Considerations:**
- Use semantic versioning for both `version` (app package) and `app_version` (MAAS software)
- Set `run_as_context` to non-root user (uid/gid 1000) unless MAAS absolutely requires root
- Include comprehensive keywords for discoverability in the app catalog
- Provide high-quality screenshots (1280x720 or higher) for the app gallery
- Use the `community` train for initial development, graduate to `stable` after testing

**Sources:**
- [TrueNAS App YAML Example](https://github.com/truenas/apps/blob/master/ix-dev/stable/plex/app.yaml)
- [TrueNAS Apps Structure](https://github.com/truenas/charts/blob/master/README.md)

#### 2. Docker Compose Configuration (`compose.yaml` or `docker-compose.yaml`)

This file defines the container services, networking, and volumes:

```yaml
name: maas

services:
  maas:
    image: ${IMAGE_REPOSITORY}:${IMAGE_TAG}
    container_name: maas
    restart: unless-stopped

    # Network configuration
    network_mode: ${NETWORK_MODE:-bridge}
    ports:
      - "${MAAS_HTTP_PORT:-5240}:5240"        # HTTP UI/API
      - "${MAAS_HTTPS_PORT:-5443}:5443"       # HTTPS UI/API (if enabled)
      - "${TFTP_PORT:-69}:69/udp"             # TFTP for PXE boot

    # Environment variables
    environment:
      - TZ=${TZ:-Etc/UTC}
      - MAAS_URL=${MAAS_URL}                  # MAAS server URL
      - MAAS_ADMIN_USERNAME=${MAAS_ADMIN_USERNAME:-admin}
      - MAAS_ADMIN_PASSWORD=${MAAS_ADMIN_PASSWORD}
      - MAAS_ADMIN_EMAIL=${MAAS_ADMIN_EMAIL}
      - POSTGRES_HOST=${POSTGRES_HOST:-postgres}
      - POSTGRES_PORT=${POSTGRES_PORT:-5432}
      - POSTGRES_DB=${POSTGRES_DB:-maasdb}
      - POSTGRES_USER=${POSTGRES_USER:-maas}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

    # Volume mounts
    volumes:
      - ${MAAS_CONFIG_PATH}:/etc/maas:rw
      - ${MAAS_DATA_PATH}:/var/lib/maas:rw
      - ${MAAS_IMAGES_PATH}:/var/lib/maas/boot-resources:rw
      - ${MAAS_LOGS_PATH}:/var/log/maas:rw

    # Security settings
    user: "${RUN_AS_USER:-1000}:${RUN_AS_GROUP:-1000}"
    cap_add:
      - NET_ADMIN
      - NET_RAW

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5240/MAAS/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:15-alpine
    container_name: maas-postgres
    restart: unless-stopped

    environment:
      - POSTGRES_DB=${POSTGRES_DB:-maasdb}
      - POSTGRES_USER=${POSTGRES_USER:-maas}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - PGDATA=/var/lib/postgresql/data/pgdata

    volumes:
      - ${POSTGRES_DATA_PATH}:/var/lib/postgresql/data:rw

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-maas}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  maas-config:
    driver: local
  maas-data:
    driver: local
  maas-images:
    driver: local
  postgres-data:
    driver: local

networks:
  default:
    driver: bridge
```

**Important Docker Compose Best Practices:**

1. **Variable Substitution**: Use `${VARIABLE:-default}` syntax for all configurable values
2. **Top-Level Elements**: Always start with `name:` or `services:` as the top-level element
3. **Restart Policy**: Use `unless-stopped` for production services
4. **Health Checks**: Implement health checks for all services with dependencies
5. **Network Mode**: Support both `bridge` (default) and `host` networking via variable
6. **Security**: Run as non-root user when possible using the `user:` directive
7. **Volume Management**: Use named volumes or host path bind mounts (not ixVolumes for production)

**Sources:**
- [TrueNAS Custom Apps Documentation](https://www.truenas.com/docs/truenasapps/usingcustomapp/)
- [Docker Compose on TrueNAS](https://forums.truenas.com/t/docker-compose-install-via-yaml-thank-you-ix/22343)

#### 3. Application Configuration UI (Optional: `questions.yaml`)

For catalog apps (not custom apps), define user-facing configuration questions:

```yaml
groups:
  - name: "MAAS Configuration"
    description: "Configure MAAS server settings"
  - name: "Database Configuration"
    description: "PostgreSQL database settings"
  - name: "Network Configuration"
    description: "Network and port settings"
  - name: "Storage Configuration"
    description: "Persistent storage paths"

questions:
  # MAAS Configuration
  - variable: MAAS_URL
    label: "MAAS Server URL"
    description: "The full URL where MAAS will be accessible (e.g., http://192.168.1.100:5240/MAAS)"
    group: "MAAS Configuration"
    schema:
      type: string
      required: true
      default: ""

  - variable: MAAS_ADMIN_USERNAME
    label: "Admin Username"
    description: "MAAS administrator username"
    group: "MAAS Configuration"
    schema:
      type: string
      required: true
      default: "admin"

  - variable: MAAS_ADMIN_PASSWORD
    label: "Admin Password"
    description: "MAAS administrator password (minimum 8 characters)"
    group: "MAAS Configuration"
    schema:
      type: string
      required: true
      private: true
      min_length: 8

  - variable: MAAS_ADMIN_EMAIL
    label: "Admin Email"
    description: "Email address for the MAAS administrator"
    group: "MAAS Configuration"
    schema:
      type: string
      required: true
      default: ""

  # Network Configuration
  - variable: MAAS_HTTP_PORT
    label: "HTTP Port"
    description: "Port for MAAS HTTP interface"
    group: "Network Configuration"
    schema:
      type: int
      required: true
      default: 5240
      min: 1024
      max: 65535

  - variable: NETWORK_MODE
    label: "Network Mode"
    description: "Docker network mode (bridge recommended for most setups)"
    group: "Network Configuration"
    schema:
      type: string
      required: true
      default: "bridge"
      enum:
        - value: "bridge"
          description: "Bridge network (isolated)"
        - value: "host"
          description: "Host network (direct access)"

  # Storage Configuration
  - variable: MAAS_CONFIG_PATH
    label: "MAAS Configuration Path"
    description: "Host path for MAAS configuration files"
    group: "Storage Configuration"
    schema:
      type: hostpath
      required: true

  - variable: MAAS_DATA_PATH
    label: "MAAS Data Path"
    description: "Host path for MAAS persistent data"
    group: "Storage Configuration"
    schema:
      type: hostpath
      required: true

  - variable: MAAS_IMAGES_PATH
    label: "Boot Images Path"
    description: "Host path for OS boot images (requires significant space)"
    group: "Storage Configuration"
    schema:
      type: hostpath
      required: true

  # Database Configuration
  - variable: POSTGRES_PASSWORD
    label: "PostgreSQL Password"
    description: "Password for PostgreSQL database"
    group: "Database Configuration"
    schema:
      type: string
      required: true
      private: true
      min_length: 8
```

**Notes on questions.yaml:**
- This file is only needed for apps in the official TrueNAS catalog
- For custom app deployments, users configure via Docker Compose YAML directly
- Group related questions for better UX
- Mark sensitive fields with `private: true`
- Use `hostpath` type for storage paths to ensure proper TrueNAS dataset selection

**Sources:**
- [TrueNAS Charts Structure](https://github.com/truenas/charts/blob/master/README.md)

#### 4. Documentation (`README.md` and `app-readme.md`)

**app-readme.md** (Brief overview for catalog):
```markdown
# MAAS - Metal as a Service

MAAS provides automated bare metal server provisioning and lifecycle management.

## Features
- Automated server discovery and provisioning
- OS deployment in under 2 minutes
- Power management (IPMI, Redfish, etc.)
- Network and storage configuration
- RESTful API for automation
- Integration with Kubernetes, OpenStack, and cloud platforms

## Quick Start
1. Configure MAAS server URL and admin credentials
2. Set PostgreSQL database password
3. Configure storage paths for config, data, and boot images
4. Access MAAS UI at configured port (default: 5240)

## Post-Installation
1. Import boot images for desired operating systems
2. Configure network subnets and DHCP
3. Add physical machines via IPMI/BMC or manual enrollment
4. Commission and deploy machines

For detailed documentation, visit https://maas.io/docs
```

**README.md** (Comprehensive developer documentation):
```markdown
# MAAS App for TrueNAS

This TrueNAS application provides integration with Canonical's MAAS (Metal as a Service)
for automated bare metal server provisioning and lifecycle management.

## Architecture

This app consists of two containers:
- **maas**: Main MAAS server (region + rack controller)
- **postgres**: PostgreSQL database for MAAS data persistence

## Prerequisites

- **TrueNAS 25.10.0 or later** (required for modern API and Docker Compose features)
- Minimum 4GB RAM allocated to app
- Minimum 100GB storage for boot images
- Network access for PXE booting physical machines
- If using TrueNAS API integration: JSON-RPC 2.0 WebSocket client (not REST)

## Installation

### Via TrueNAS UI

1. Navigate to Apps > Discover Apps
2. Search for "MAAS"
3. Click Install and configure:
   - MAAS server URL (must be accessible from managed machines)
   - Admin credentials
   - Storage paths
   - Network ports

### Via Custom App (Docker Compose)

1. Create datasets for storage:
   - /mnt/pool/maas/config
   - /mnt/pool/maas/data
   - /mnt/pool/maas/images
   - /mnt/pool/maas/postgres

2. Install as custom app with provided compose.yaml

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| MAAS_URL | MAAS server URL | - | Yes |
| MAAS_ADMIN_USERNAME | Admin username | admin | Yes |
| MAAS_ADMIN_PASSWORD | Admin password | - | Yes |
| MAAS_ADMIN_EMAIL | Admin email | - | Yes |
| POSTGRES_PASSWORD | Database password | - | Yes |
| MAAS_HTTP_PORT | HTTP port | 5240 | No |
| TZ | Timezone | Etc/UTC | No |

### Storage Volumes

- **/etc/maas**: Configuration files
- **/var/lib/maas**: Application data
- **/var/lib/maas/boot-resources**: OS boot images (100GB+ recommended)
- **/var/log/maas**: Log files

### Network Configuration

**Bridge Mode (Recommended):**
- HTTP: Port 5240
- TFTP: Port 69/UDP

**Host Mode (For PXE Boot):**
- Direct access to host network
- Required for machines to PXE boot from MAAS

## Post-Installation Setup

1. **Access Web UI**: Navigate to http://<truenas-ip>:5240/MAAS/
2. **Login**: Use configured admin credentials
3. **Import Boot Images**:
   ```bash
   # Via MAAS CLI (exec into container)
   maas admin boot-resources import
   ```
4. **Configure Networks**: Set up subnets, DHCP, and DNS
5. **Add Machines**: Enroll physical servers via IPMI or manual registration

## Usage Examples

### Commissioning a Machine

```bash
# Get API key
maas login admin http://localhost:5240/MAAS/api/2.0/

# Commission a machine
maas admin machine commission <system-id>
```

### Deploying Ubuntu

```bash
maas admin machine deploy <system-id> distro_series=jammy
```

## Troubleshooting

### Container won't start
- Check logs: `docker logs maas`
- Verify PostgreSQL is healthy
- Ensure storage paths are accessible

### PXE boot not working
- Use host networking mode
- Verify TFTP port 69/UDP is accessible
- Check firewall rules on TrueNAS

### Images not downloading
- Check internet connectivity from container
- Verify sufficient storage space
- Review logs at /var/log/maas/

## API Integration

MAAS provides a full REST API at `/MAAS/api/2.0/`:

```python
from maas.client import connect

client = await connect(
    "http://maas-server:5240/MAAS/api/2.0/",
    apikey="<your-api-key>"
)

machines = client.machines.list()
```

## Security Considerations

- Change default admin password immediately
- Use strong PostgreSQL password
- Restrict network access to MAAS UI
- Enable HTTPS in production (configure reverse proxy)
- Regularly update MAAS to latest version

## Support

- MAAS Documentation: https://maas.io/docs
- MAAS Discourse: https://discourse.maas.io
- GitHub Issues: https://github.com/yourusername/truenas-maas-app

## License

MAAS is licensed under AGPL-3.0. This TrueNAS app integration is licensed under MIT.
```

### TrueNAS Storage Best Practices

**Critical Storage Requirements:**

1. **Use Host Path Volumes for Production**
   - Do NOT use `ixVolumes` for production deployments
   - Create dedicated datasets before app installation
   - Recommended structure:
     ```
     /mnt/<pool>/apps/maas/
     ├── config/
     ├── data/
     ├── images/     (100GB+ for boot images)
     ├── logs/
     └── postgres/
     ```

2. **Storage Performance**
   - Use SSD storage for the apps pool
   - Boot images dataset can be on HDD (large, sequential reads)
   - Database (PostgreSQL) should be on SSD for performance

3. **Volume Mount Permissions**
   - Ensure UID/GID match between container and host
   - Set appropriate directory ownership before deployment:
     ```bash
     chown -R 1000:1000 /mnt/pool/apps/maas/
     ```

4. **Storage Requirements**
   - Config: 100MB
   - Data: 10GB minimum
   - Images: 100GB+ (depends on number of OS images)
   - Logs: 5GB recommended
   - PostgreSQL: 20GB minimum

**Sources:**
- [TrueNAS App Storage Best Practices](https://www.truenas.com/docs/truenasapps/)
- [Storage Configuration](https://www.truenas.com/docs/solutions/optimizations/networking/)

### TrueNAS Network Configuration

**Network Mode Selection:**

1. **Bridge Mode (Default)**
   - Pros: Isolated network, port mapping, security
   - Cons: NAT overhead, port conflicts possible
   - Best for: General use, web UI access only
   - Configuration:
     ```yaml
     network_mode: bridge
     ports:
       - "5240:5240"
       - "69:69/udp"
     ```

2. **Host Mode**
   - Pros: Direct network access, no NAT, required for PXE
   - Cons: No network isolation, potential security risk
   - Best for: PXE boot server, DHCP server
   - Configuration:
     ```yaml
     network_mode: host
     # No port mapping needed
     ```

**Port Requirements:**
- 5240/tcp: HTTP API/UI
- 5443/tcp: HTTPS API/UI (optional)
- 69/udp: TFTP (PXE boot)
- 5248-5270/tcp: Region-rack communication (multi-node)

**Network Isolation Best Practice:**
- Run storage traffic on separate subnet from MAAS traffic
- Use VLAN tagging for management network
- Implement Quality of Service (QoS) for storage priority

**Sources:**
- [TrueNAS Networking Best Practices](https://www.truenas.com/docs/solutions/optimizations/networking/)

### Security Best Practices

**Container Security:**

1. **Run as Non-Root**
   ```yaml
   user: "1000:1000"  # Non-root UID/GID
   ```

2. **Limit Capabilities**
   ```yaml
   cap_add:
     - NET_ADMIN  # Only add required capabilities
     - NET_RAW
   cap_drop:
     - ALL        # Drop all others
   ```

3. **Read-Only Filesystem** (where possible)
   ```yaml
   volumes:
     - ${MAAS_CONFIG_PATH}:/etc/maas:ro  # Read-only config
   ```

4. **Secrets Management**
   - Never hardcode passwords in compose.yaml
   - Use environment variable substitution
   - Store sensitive values in TrueNAS environment configuration
   - Consider using Docker secrets for production:
     ```yaml
     secrets:
       postgres_password:
         file: /run/secrets/postgres_password
     ```

**Network Security:**
- Disable any unused network services
- Restrict MAAS web UI to private subnet
- Use VPN for remote access
- Enable HTTPS with valid TLS certificates
- Implement firewall rules on TrueNAS

**Application Security:**
- Change default credentials immediately
- Use strong passwords (16+ characters, mixed case, symbols)
- Enable two-factor authentication if available
- Regularly update MAAS to patch vulnerabilities
- Monitor logs for suspicious activity

**Sources:**
- [TrueNAS Security Recommendations](https://www.truenas.com/docs/solutions/optimizations/security/)
- [Security Best Practices](https://www.truenas.com/community/threads/security-best-practices.75820/)

## MAAS API Integration Guide

### Authentication

MAAS uses 3-legged OAuth 1.0a authentication. The API key format is:
```
<consumer_key>:<token_key>:<token_secret>
```

**Python Example (using python-libmaas):**

```python
import asyncio
from maas.client import connect

async def main():
    # Connect to MAAS
    client = await connect(
        "http://maas-server:5240/MAAS/api/2.0/",
        apikey="<consumer>:<token>:<secret>"
    )

    # List all machines
    machines = await client.machines.list()
    for machine in machines:
        print(f"{machine.hostname}: {machine.status_name}")

    # Get machine details
    machine = await client.machines.get(system_id="abc123")
    print(f"CPU: {machine.cpu_count} cores")
    print(f"Memory: {machine.memory / 1024}GB")

    # Commission a machine
    await machine.commission(
        commissioning_scripts=['update_firmware', 'internet_connectivity'],
        wait=True  # Wait for commissioning to complete
    )

    # Deploy Ubuntu 22.04
    await machine.deploy(
        distro_series='jammy',
        user_data='#cloud-config\n...',
        wait=True
    )

    await client.close()

asyncio.run(main())
```

**Sources:**
- [python-libmaas Documentation](https://github.com/canonical/python-libmaas)
- [MAAS API Authentication](https://maas.io/docs/how-to-authenticate-to-the-maas-api)

### Key API Endpoints

**Machines Management:**

```bash
# List all machines
GET /MAAS/api/2.0/machines/

# Get machine details
GET /MAAS/api/2.0/machines/{system_id}/

# Commission a machine
POST /MAAS/api/2.0/machines/{system_id}/?op=commission

# Deploy a machine
POST /MAAS/api/2.0/machines/{system_id}/?op=deploy
  Parameters: distro_series, hwe_kernel, user_data

# Release (power off and return to pool)
POST /MAAS/api/2.0/machines/{system_id}/?op=release

# Power control
POST /MAAS/api/2.0/machines/{system_id}/?op=power_on
POST /MAAS/api/2.0/machines/{system_id}/?op=power_off
```

**Network Configuration:**

```bash
# List subnets
GET /MAAS/api/2.0/subnets/

# Create subnet
POST /MAAS/api/2.0/subnets/
  Parameters: cidr, name, vlan

# List VLANs
GET /MAAS/api/2.0/vlans/

# Configure DHCP
POST /MAAS/api/2.0/vlans/{vlan_id}/?op=enable_dhcp
```

**Boot Resources:**

```bash
# List boot images
GET /MAAS/api/2.0/boot-resources/

# Import boot images
POST /MAAS/api/2.0/boot-resources/?op=import

# Get import status
GET /MAAS/api/2.0/boot-resources/?op=is_importing
```

**Sources:**
- [MAAS API Documentation](https://canonical.com/maas/docs/api)
- [MAAS REST API Examples](https://discourse.maas.io/t/rest-api-deploy/6553)

### Machine Lifecycle Operations

**1. Discovery → 2. Commissioning → 3. Ready → 4. Deployment → 5. Deployed**

```python
async def provision_machine_workflow(client, mac_address):
    """Complete workflow for provisioning a new machine"""

    # Step 1: Discover (automatic via PXE boot)
    # Machine boots, MAAS detects it automatically

    # Step 2: Find the new machine
    machines = await client.machines.list()
    machine = next(m for m in machines if mac_address in m.mac_addresses)

    # Step 3: Commission (gather hardware info)
    await machine.commission(
        commissioning_scripts=[
            'update_firmware',           # Update BMC firmware
            'internet_connectivity',     # Test internet
            'smartctl-validate',        # Check disk health
        ],
        testing_scripts=[
            'cpu-stress',               # CPU stress test
            'memory-stress',            # RAM stress test
        ],
        wait=True
    )

    # Step 4: Tag the machine (optional)
    await machine.add_tag('kubernetes-node')
    await machine.add_tag('ssd-storage')

    # Step 5: Configure storage
    await machine.set_storage_layout('lvm', boot_size='10G')

    # Step 6: Deploy OS
    await machine.deploy(
        distro_series='jammy',          # Ubuntu 22.04
        hwe_kernel='hwe-22.04',         # Hardware enablement kernel
        user_data=cloud_init_config,    # Cloud-init configuration
        wait=True
    )

    # Step 7: Wait for deployment
    while machine.status_name != 'Deployed':
        await asyncio.sleep(10)
        await machine.refresh()

    return machine
```

**Sources:**
- [MAAS Commissioning](https://maas.io/docs/commission-nodes)
- [python-libmaas Node Operations](https://github.com/canonical/python-libmaas/blob/master/doc/client/nodes.md)

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

**Objective**: Create functional TrueNAS app package with MAAS deployment

**Tasks:**

1. **Set up project structure**
   ```
   truenas-maas-app/
   ├── ix-dev/
   │   └── community/
   │       └── maas/
   │           ├── app.yaml              # App metadata
   │           ├── docker-compose.yaml   # Container definitions
   │           ├── app-readme.md         # Catalog description
   │           └── icon.png              # App icon (512x512)
   ├── docs/
   │   └── README.md                     # Comprehensive documentation
   ├── scripts/
   │   ├── init-maas.sh                  # First-run initialization
   │   └── backup.sh                     # Backup script
   ├── tests/
   │   └── integration-tests.py          # Integration tests
   └── README.md                         # Project README
   ```

2. **Create base Docker Compose configuration**
   - MAAS region+rack controller service
   - PostgreSQL database service
   - Volume mounts for persistence
   - Network configuration (bridge and host modes)
   - Health checks for both services

3. **Create app.yaml with complete metadata**
   - All required fields populated
   - Security context configured for non-root
   - Icon and screenshots prepared
   - Keywords and categories set

4. **Implement initialization script**
   - First-run database setup
   - Admin user creation
   - API key generation
   - Basic configuration

**Success Criteria:**
- App installs successfully on TrueNAS 25.10+
- MAAS web UI accessible on configured port
- PostgreSQL database healthy and connected
- Admin user can log in
- All containers running as non-root
- Data persists after container restart
- No deprecated API warnings (if TrueNAS integration used)

### Phase 2: Configuration & UI (Week 2)

**Objective**: Enhance user experience with proper configuration options

**Tasks:**

1. **Create questions.yaml for catalog deployment**
   - MAAS server configuration
   - Database settings
   - Network options
   - Storage paths
   - Security settings

2. **Add environment variable validation**
   - Check required variables are set
   - Validate URL formats
   - Ensure password complexity
   - Verify port ranges

3. **Implement configuration templates**
   - MAAS settings templates
   - Network configuration templates
   - Storage layout templates

4. **Create comprehensive documentation**
   - Installation guide
   - Configuration reference
   - Troubleshooting guide
   - API integration examples

**Success Criteria:**
- User-friendly installation wizard
- Clear error messages for misconfigurations
- All configuration options documented
- Examples for common use cases

### Phase 3: Integration & Automation (Week 3)

**Objective**: Enable advanced MAAS features and automation

**Tasks:**

1. **Implement MAAS API client wrapper**
   ```python
   class MAASClient:
       """Python client for MAAS API integration"""

       async def discover_machines(self) -> List[Machine]:
           """Discover machines on network"""

       async def commission_machine(self, system_id: str) -> bool:
           """Commission a machine"""

       async def deploy_machine(self, system_id: str, os: str) -> bool:
           """Deploy OS to machine"""

       async def get_machine_status(self, system_id: str) -> str:
           """Get machine deployment status"""
   ```

2. **Create automation scripts**
   - Bulk machine provisioning
   - Automated commissioning workflows
   - OS image management
   - Network configuration automation

3. **Add monitoring and logging**
   - Container health monitoring
   - MAAS service status checks
   - Log aggregation
   - Alert configuration

4. **Implement backup/restore**
   - Database backup script
   - Configuration export
   - Boot images backup (optional)
   - Restore procedure

**Success Criteria:**
- Python client library functional
- Automation scripts tested with real hardware
- Monitoring dashboards operational
- Backup/restore procedure verified

### Phase 4: Testing & Documentation (Week 4)

**Objective**: Comprehensive testing and production-ready documentation

**Tasks:**

1. **Integration testing**
   - Test on TrueNAS 24.10+ with various configurations
   - Test with physical servers (IPMI, Redfish)
   - Test PXE boot workflows
   - Test database persistence and recovery
   - Test network modes (bridge, host)

2. **Security audit**
   - Review container security settings
   - Test with non-root user
   - Verify secret management
   - Check for exposed credentials
   - Test network isolation

3. **Performance testing**
   - Concurrent machine deployments
   - Database query performance
   - Image download performance
   - Resource usage profiling

4. **Documentation completion**
   - Architecture diagrams
   - API reference with examples
   - Troubleshooting guide
   - Video tutorials (optional)
   - Contributing guidelines

**Success Criteria:**
- All tests passing
- No critical security issues
- Performance meets requirements
- Documentation complete and clear
- Ready for community beta testing

### Phase 5: Community Release (Week 5)

**Objective**: Release to TrueNAS community and gather feedback

**Tasks:**

1. **Prepare release package**
   - Final version bump
   - Changelog creation
   - Release notes
   - GitHub release

2. **Submit to TrueNAS catalog**
   - Create pull request to truenas/apps
   - Address review comments
   - Meet catalog requirements

3. **Community engagement**
   - Post announcement on TrueNAS forums
   - Create discussion thread
   - Provide support for early adopters
   - Collect feedback

4. **Iterate based on feedback**
   - Bug fixes
   - Feature requests
   - Documentation improvements
   - Performance optimizations

**Success Criteria:**
- App available in TrueNAS community catalog
- Positive community feedback
- No critical bugs reported
- Documentation rated helpful

## Testing Strategy

### Unit Tests

```python
# tests/test_maas_client.py
import pytest
from maas_client import MAASClient

@pytest.mark.asyncio
async def test_connect_to_maas():
    """Test connection to MAAS API"""
    client = MAASClient(
        url="http://localhost:5240/MAAS/api/2.0/",
        apikey="test:key:secret"
    )
    assert await client.ping()

@pytest.mark.asyncio
async def test_list_machines():
    """Test listing machines"""
    client = MAASClient(url, apikey)
    machines = await client.machines.list()
    assert isinstance(machines, list)
```

### Integration Tests

```python
# tests/integration_test.py
import docker
import pytest
import asyncio

@pytest.fixture
async def maas_container():
    """Start MAAS container for testing"""
    client = docker.from_env()

    # Start containers via compose
    container = client.containers.run(
        "maas:test",
        detach=True,
        ports={"5240/tcp": 5240}
    )

    # Wait for MAAS to be ready
    await wait_for_maas(container)

    yield container

    # Cleanup
    container.stop()
    container.remove()

async def test_full_provisioning_workflow(maas_container):
    """Test complete machine provisioning workflow"""
    client = MAASClient(...)

    # Test machine discovery
    machines = await client.machines.list()
    assert len(machines) > 0

    # Test commissioning
    machine = machines[0]
    await machine.commission()
    assert machine.status_name == "Ready"

    # Test deployment
    await machine.deploy(distro_series="jammy")
    assert machine.status_name == "Deployed"
```

### Manual Testing Checklist

**Installation:**
- [ ] Fresh install on TrueNAS 25.10+
- [ ] Upgrade from previous version (if applicable)
- [ ] Installation with custom storage paths
- [ ] Installation with host networking
- [ ] Verification of JSON-RPC API compatibility (if TrueNAS integration used)

**Functionality:**
- [ ] Web UI accessible
- [ ] Admin login successful
- [ ] Boot image import works
- [ ] Machine discovery via PXE
- [ ] IPMI/BMC power control
- [ ] Machine commissioning
- [ ] OS deployment (Ubuntu, CentOS)
- [ ] API authentication
- [ ] API operations (list, deploy, release)

**Performance:**
- [ ] Deploy 10 machines concurrently
- [ ] Database performance under load
- [ ] Boot image download speed
- [ ] Web UI responsiveness

**Security:**
- [ ] Containers run as non-root
- [ ] No hardcoded credentials
- [ ] Network isolation effective
- [ ] Log files not world-readable

**Persistence:**
- [ ] Data survives container restart
- [ ] Database survives container restart
- [ ] Configuration persists
- [ ] Boot images persist

## Success Criteria

### Functional Requirements

**Must Have:**
1. App installs successfully on TrueNAS 25.10+
2. MAAS web UI accessible and functional
3. Can discover physical machines via PXE boot
4. Can commission machines to gather hardware info
5. Can deploy Ubuntu/CentOS to bare metal
6. API authentication and operations work
7. Data persists across container restarts
8. Comprehensive documentation provided
9. Compatible with TrueNAS 25.10+ features (JSON-RPC API if TrueNAS integration used)

**Should Have:**
1. Support for both bridge and host networking
2. Configurable storage paths
3. Database backup/restore functionality
4. Health monitoring and logging
5. Python client library for automation
6. Example scripts for common workflows

**Nice to Have:**
1. Web-based dashboard for TrueNAS integration
2. Webhook notifications for events
3. Integration with TrueNAS storage provisioning
4. Terraform provider integration
5. Kubernetes cluster deployment templates

### Non-Functional Requirements

**Performance:**
- Deploy 5+ machines concurrently
- UI response time < 500ms
- API response time < 200ms
- Support 100+ machines in inventory

**Security:**
- Run all containers as non-root
- No hardcoded credentials
- Support HTTPS/TLS
- Regular security updates

**Reliability:**
- 99%+ uptime for MAAS services
- Automatic recovery from container failures
- Database backup every 24 hours
- Log rotation configured

**Maintainability:**
- Clear code documentation
- Comprehensive test coverage (>80%)
- CI/CD pipeline for testing
- Semantic versioning

## Common Pitfalls to Avoid

1. **Running as Root**: Always use non-root user in containers unless absolutely required
2. **Hardcoded Credentials**: Use environment variables for all sensitive data
3. **ixVolumes in Production**: Use host path volumes for production deployments
4. **Missing Health Checks**: Always implement health checks for services with dependencies
5. **Insufficient Storage**: Allocate adequate space for boot images (100GB+)
6. **Bridge Mode for PXE**: PXE boot requires host networking mode
7. **Weak Passwords**: Enforce strong password requirements
8. **No Backup Strategy**: Implement and document backup/restore procedures
9. **Poor Documentation**: Document all configuration options and common issues
10. **Ignoring Security**: Follow TrueNAS and Docker security best practices

## Additional Resources

### TrueNAS Resources
- [TrueNAS Apps Documentation](https://www.truenas.com/docs/truenasapps/)
- [TrueNAS Apps Repository](https://github.com/truenas/apps)
- [TrueNAS Apps Market](https://apps.truenas.com/)
- [TrueNAS Community Forums](https://forums.truenas.com/)
- [TrueNAS Security Best Practices](https://www.truenas.com/docs/solutions/optimizations/security/)
- [TrueNAS Networking Best Practices](https://www.truenas.com/docs/solutions/optimizations/networking/)

### MAAS Resources
- [MAAS Official Documentation](https://maas.io/docs)
- [MAAS API Reference](https://canonical.com/maas/docs/api)
- [python-libmaas GitHub](https://github.com/canonical/python-libmaas)
- [MAAS Discourse Community](https://discourse.maas.io)
- [MAAS GitHub Repository](https://github.com/canonical/maas)
- [MAAS Python Client Tutorial](https://maas.io/docs/python-api-client-reference)

### Docker & Compose
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Networking](https://docs.docker.com/network/)

## Deliverables

Upon completion, the following should be ready:

1. **Source Code**
   - Complete TrueNAS app package in `ix-dev/` structure
   - Docker Compose configuration
   - Initialization scripts
   - Backup/restore scripts

2. **Documentation**
   - README.md with installation instructions
   - API integration guide with examples
   - Troubleshooting guide
   - Architecture documentation

3. **Tests**
   - Unit tests for Python code
   - Integration tests for workflows
   - Manual testing checklist

4. **Assets**
   - App icon (512x512 PNG)
   - Screenshots (1280x720 or higher)
   - Video tutorial (optional)

5. **Release Package**
   - GitHub release with changelog
   - Pull request to truenas/apps repository
   - Community announcement

## Final Notes

This prompt provides a comprehensive blueprint for building a production-ready MAAS integration app for TrueNAS. The architecture follows TrueNAS best practices while leveraging MAAS's powerful bare metal provisioning capabilities.

**Key Success Factors:**
- Follow TrueNAS app structure exactly
- Prioritize security and data persistence
- Provide excellent documentation
- Test thoroughly before release
- Engage with the community

**Estimated Timeline:** 5 weeks for complete implementation, testing, and community release.

**Required Skills:**
- Docker & Docker Compose
- Python (for automation scripts)
- YAML configuration
- Linux networking
- REST API integration
- Technical documentation

Good luck building this integration! The combination of TrueNAS's storage capabilities and MAAS's bare metal provisioning creates a powerful infrastructure management platform.
