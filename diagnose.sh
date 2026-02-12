#!/bin/bash
# MAAS Fresh Install Diagnostic Script
# Run this on TrueNAS to gather debugging information

echo "=== MAAS Fresh Install Diagnostics ==="
echo "Timestamp: $(date)"
echo ""

echo "=== Git Repository Status ==="
cd /mnt/pool0/maas/truenas-maas-app
git log --oneline -5
echo ""

echo "=== .env File Check ==="
if [ -f .env ]; then
    echo ".env file exists"
    echo "POSTGRES_PASSWORD set: $(grep -q POSTGRES_PASSWORD .env && echo 'YES' || echo 'NO')"
    echo "MAAS_ADMIN_PASSWORD set: $(grep -q MAAS_ADMIN_PASSWORD .env && echo 'YES' || echo 'NO')"
    echo "POSTGRES_HOST: $(grep POSTGRES_HOST .env | cut -d= -f2)"
else
    echo "ERROR: .env file does not exist!"
fi
echo ""

echo "=== Directory Ownership ==="
ls -la /mnt/pool0/maas/ | head -15
echo ""

echo "=== Docker Compose Container Status ==="
sudo docker compose ps -a
echo ""

echo "=== PostgreSQL Logs (last 50 lines) ==="
sudo docker compose logs postgres | tail -50
echo ""

echo "=== MAAS Logs (last 100 lines) ==="
sudo docker compose logs maas | tail -100
echo ""

echo "=== Docker Images ==="
sudo docker images | grep -E 'truenas-maas|postgres'
echo ""

echo "=== Network Status ==="
sudo docker network ls | grep maas
echo ""

echo "=== Port Bindings ==="
sudo netstat -tuln | grep -E '5432|5240'
echo ""

echo "=== Disk Space ==="
df -h /mnt/pool0/maas/
echo ""

echo "=== PostgreSQL Data Directory ==="
ls -la /mnt/pool0/maas/postgres/
echo ""

echo "=== MAAS Config Directory ==="
ls -la /mnt/pool0/maas/config/
echo ""
