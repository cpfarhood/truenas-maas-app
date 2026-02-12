# TrueNAS MAAS Application - Custom Dockerfile
# Version: 1.0.0
# Base: Ubuntu 22.04 LTS (MAAS recommended base)
# MAAS Version: 3.5
# Optimized for TrueNAS 25.10+ with non-root operation

FROM ubuntu:22.04

LABEL maintainer="TrueNAS MAAS Application"
LABEL version="1.0.0"
LABEL description="MAAS 3.5 optimized for TrueNAS 25.10+ with non-root operation"
LABEL maas.version="3.5"

# Build arguments
ARG MAAS_VERSION=3.5
ARG MAAS_UID=568
ARG MAAS_GID=568
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables
ENV MAAS_UID=${MAAS_UID} \
    MAAS_GID=${MAAS_GID} \
    MAAS_USER=maas \
    MAAS_GROUP=maas \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies and utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    # Network tools
    iproute2 \
    iputils-ping \
    netcat \
    dnsutils \
    # PostgreSQL client for database operations
    postgresql-client \
    # Python and pip for MAAS
    python3 \
    python3-pip \
    python3-setuptools \
    # System utilities
    sudo \
    tzdata \
    # Systemd for service management in container
    systemd \
    systemd-sysv \
    dbus \
    && rm -rf /var/lib/apt/lists/*

# Configure systemd for container operation
# Remove unnecessary systemd services and targets
RUN cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 || true && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp*

# Configure systemd defaults for container
RUN systemctl set-default multi-user.target

# Add MAAS PPA and install MAAS
RUN add-apt-repository -y ppa:maas/${MAAS_VERSION} && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # MAAS region controller and dependencies
    maas \
    maas-region-api \
    maas-common \
    # DHCP server
    maas-dhcp \
    # DNS server
    maas-dns \
    # HTTP proxy
    maas-proxy \
    # Additional utilities
    nginx \
    squid \
    bind9 \
    && rm -rf /var/lib/apt/lists/*

# Modify MAAS user and group to use UID/GID 568 (TrueNAS requirement)
# MAAS package creates user/group during installation, so we modify them
RUN groupmod -g ${MAAS_GID} ${MAAS_GROUP} && \
    usermod -u ${MAAS_UID} -g ${MAAS_GID} -d /var/lib/maas -s /bin/bash ${MAAS_USER} && \
    # Add to sudo group for specific operations
    usermod -aG sudo ${MAAS_USER} && \
    # Configure passwordless sudo with environment preservation for MAAS commands
    echo "Defaults:maas !requiretty" > /etc/sudoers.d/maas && \
    echo "maas ALL=(ALL) NOPASSWD: SETENV: /usr/sbin/maas-region, /usr/bin/maas, /usr/bin/twistd3" >> /etc/sudoers.d/maas && \
    chmod 0440 /etc/sudoers.d/maas

# Create necessary directories with proper ownership
# Based on MAAS runtime requirements and Airship MAAS containerization patterns
RUN mkdir -p \
    /etc/maas \
    /var/lib/maas \
    /var/lib/maas/boot-resources \
    /var/lib/maas/gnupg-home \
    /var/lib/maas/image-storage \
    /var/lib/maas/image-storage/bootloaders \
    /var/lib/maas/temporal-storage \
    /var/lib/maas/certificates \
    /var/lib/maas/http \
    /var/lib/maas/prometheus \
    /var/log/maas \
    /var/spool/maas-proxy \
    /run/lock/maas \
    /tmp/maas && \
    # Set ownership to maas user
    chown -R ${MAAS_UID}:${MAAS_GID} \
    /etc/maas \
    /var/lib/maas \
    /var/log/maas \
    /var/spool/maas-proxy \
    /run/lock/maas \
    /tmp/maas && \
    # Set proper permissions
    chmod -R 755 /etc/maas && \
    chmod -R 755 /var/lib/maas && \
    chmod -R 755 /var/log/maas && \
    chmod -R 755 /var/spool/maas-proxy && \
    chmod -R 755 /run/lock/maas && \
    chmod 1777 /tmp/maas

# Create directories for runtime sockets and PID files
RUN mkdir -p \
    /run/maas \
    /run/nginx \
    /run/bind \
    && chown -R ${MAAS_UID}:${MAAS_GID} \
    /run/maas \
    /run/nginx \
    /run/bind

# Configure nginx to run as non-root
RUN sed -i "s/user www-data;/user ${MAAS_USER};/" /etc/nginx/nginx.conf && \
    sed -i "s|/var/log/nginx/error.log|/var/log/maas/nginx-error.log|" /etc/nginx/nginx.conf && \
    sed -i "s|/var/log/nginx/access.log|/var/log/maas/nginx-access.log|" /etc/nginx/nginx.conf && \
    # Change nginx PID file location
    sed -i "s|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|" /etc/nginx/nginx.conf && \
    # Ensure nginx directories are accessible
    chown -R ${MAAS_UID}:${MAAS_GID} /var/lib/nginx /var/log/nginx && \
    mkdir -p /var/log/nginx && \
    chown -R ${MAAS_UID}:${MAAS_GID} /var/log/nginx

# Configure bind9 to run as non-root (maas user)
RUN mkdir -p /var/cache/bind /var/lib/bind /var/log/bind && \
    chown -R ${MAAS_UID}:${MAAS_GID} /var/cache/bind /var/lib/bind /var/log/bind /etc/bind && \
    chmod -R 755 /var/cache/bind /var/lib/bind /var/log/bind && \
    # Configure bind9 to run as maas user instead of bind user
    sed -i 's/-u bind/-u maas/' /etc/default/named

# Configure squid proxy to run as non-root
RUN mkdir -p /var/log/squid /var/spool/squid && \
    chown -R ${MAAS_UID}:${MAAS_GID} /var/log/squid /var/spool/squid /etc/squid && \
    chmod -R 755 /var/log/squid /var/spool/squid

# Copy entrypoint and healthcheck scripts
COPY --chown=${MAAS_UID}:${MAAS_GID} docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=${MAAS_UID}:${MAAS_GID} docker/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chown=${MAAS_UID}:${MAAS_GID} docker/setup-nginx-config.sh /usr/local/bin/setup-nginx-config.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/setup-nginx-config.sh

# Create systemd service for nginx config generation
# This runs before maas-http to ensure nginx.conf wrapper exists
RUN cat > /etc/systemd/system/maas-nginx-setup.service << 'SYSTEMD_EOF'
[Unit]
Description=MAAS Nginx Configuration Setup
After=maas-regiond.service
Before=maas-http.service
ConditionPathExists=/var/lib/maas/http/regiond.nginx.conf

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-nginx-config.sh
RemainAfterExit=yes
User=maas

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Enable the nginx setup service
RUN systemctl enable maas-nginx-setup.service

# Expose MAAS ports
# 5240: HTTP UI/API
# 5443: HTTPS UI/API (if configured)
# 69/udp: TFTP for PXE boot
# 5241-5247: Additional region controller services
# 5248: Region controller RPC
# 5250-5270: Rack controller services
# 8000: HTTP proxy for image downloads
EXPOSE 5240 5443 69/udp 5241 5242 5243 5244 5245 5246 5247 5248 5250-5270 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

# Set working directory
WORKDIR /var/lib/maas

# Volume mount points
VOLUME ["/etc/maas", "/var/lib/maas", "/var/log/maas", "/tmp/maas"]

# Stop signal for systemd
STOPSIGNAL SIGRTMIN+3

# Run initialization script as entrypoint (runs as root for systemd compatibility)
# The entrypoint will perform initialization then exec systemd
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Start systemd as init system (manages all MAAS services)
CMD ["/sbin/init", "--log-target=console", "3>&1"]
