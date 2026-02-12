#!/bin/bash
# MAAS Nginx Configuration Wrapper Generator
# This script creates the main nginx.conf that includes MAAS-generated regiond.nginx.conf
# Called by systemd before starting maas-http service

set -e

NGINX_CONF="/var/lib/maas/http/nginx.conf"
REGIOND_CONF="/var/lib/maas/http/regiond.nginx.conf"
MAAS_UID="${MAAS_UID:-568}"
MAAS_GID="${MAAS_GID:-568}"

# Wait for MAAS regiond to generate regiond.nginx.conf
MAX_WAIT=60
WAITED=0

echo "Waiting for MAAS to generate regiond.nginx.conf..."
while [ ! -f "$REGIOND_CONF" ] && [ $WAITED -lt $MAX_WAIT ]; do
    sleep 1
    WAITED=$((WAITED + 1))
done

if [ ! -f "$REGIOND_CONF" ]; then
    echo "ERROR: regiond.nginx.conf not found after ${MAX_WAIT}s"
    exit 1
fi

echo "Found regiond.nginx.conf, generating nginx.conf wrapper..."

# Create main nginx.conf that includes MAAS region config
cat > "$NGINX_CONF" << 'NGINX_EOF'
# MAAS HTTP Server - Main Configuration
# This wrapper includes the MAAS-generated regiond.nginx.conf
user maas;
worker_processes auto;
pid /run/maas-http.pid;
error_log /var/log/maas/nginx-error.log;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/maas/nginx-access.log;

    # Include MAAS region configuration (upstream definitions and server blocks)
    include /var/lib/maas/http/regiond.nginx.conf;
}
NGINX_EOF

# Set ownership and permissions
chown $MAAS_UID:$MAAS_GID "$NGINX_CONF"
chmod 644 "$NGINX_CONF"

echo "Nginx configuration wrapper created successfully"
exit 0
