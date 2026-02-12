# TrueNAS MAAS Application - Custom PostgreSQL Dockerfile
# Version: 1.0.0
# Base: PostgreSQL 15 Alpine
# Optimized for TrueNAS 25.10+ with uid/gid 1000 support
#
# This custom image solves the PostgreSQL non-root user conflict on TrueNAS:
# - Official postgres image expects uid 999 or 70 (postgres user)
# - TrueNAS 25.10+ requires uid/gid 1000 for app containers
# - This image creates a postgres user with uid/gid 1000 and reconfigures PostgreSQL

FROM postgres:15-alpine

LABEL maintainer="TrueNAS MAAS Application"
LABEL version="1.0.0"
LABEL description="PostgreSQL 15 for TrueNAS 25.10+ with uid/gid 1000 support"

# Build arguments
ARG POSTGRES_UID=1000
ARG POSTGRES_GID=1000

# Install required utilities
RUN apk add --no-cache \
    bash \
    ca-certificates \
    su-exec \
    tzdata

# Remove the default postgres user and group (uid 70 in alpine)
RUN deluser postgres 2>/dev/null || true && \
    delgroup postgres 2>/dev/null || true

# Create postgres user and group with TrueNAS-compatible uid/gid (1000)
RUN addgroup -g ${POSTGRES_GID} postgres && \
    adduser -D -u ${POSTGRES_UID} -G postgres -h /var/lib/postgresql -s /bin/bash postgres && \
    mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 2777 /var/run/postgresql

# Create data directory and set ownership
# Note: The actual PGDATA will be on a mounted volume, but we set up the base structure
RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chmod 700 /var/lib/postgresql/data

# Copy custom initialization script for MAAS database
COPY --chown=postgres:postgres docker/postgres-init.sh /docker-entrypoint-initdb.d/01-maas-init.sh
RUN chmod +x /docker-entrypoint-initdb.d/01-maas-init.sh

# Copy optimized PostgreSQL configuration for MAAS workloads
COPY --chown=postgres:postgres docker/postgresql.conf /etc/postgresql/postgresql.conf

# Copy custom entrypoint wrapper to ensure proper permissions
COPY --chown=postgres:postgres docker/postgres-entrypoint.sh /usr/local/bin/postgres-entrypoint.sh
RUN chmod +x /usr/local/bin/postgres-entrypoint.sh

# Set environment variables
ENV POSTGRES_UID=${POSTGRES_UID} \
    POSTGRES_GID=${POSTGRES_GID} \
    PGDATA=/var/lib/postgresql/data/pgdata \
    LANG=en_US.utf8

# Expose PostgreSQL port
EXPOSE 5432

# Use custom entrypoint that handles uid 1000 properly
ENTRYPOINT ["/usr/local/bin/postgres-entrypoint.sh"]

# Default command
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
