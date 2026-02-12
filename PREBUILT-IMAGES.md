# Pre-built Docker Images

Pre-built Docker images are automatically published to GitHub Container Registry (ghcr.io) on every commit to main and on tagged releases.

## Available Images

- **MAAS**: `ghcr.io/cpfarhood/truenas-maas-app/maas:3.5`
- **PostgreSQL**: `ghcr.io/cpfarhood/truenas-maas-app/postgres:15`

## Quick Start with Pre-built Images

### Option 1: Use Environment Variables (Recommended)

Edit your `.env` file to use pre-built images:

```bash
# Add these lines to your .env file
IMAGE_REPOSITORY=ghcr.io/cpfarhood/truenas-maas-app/maas
IMAGE_TAG=3.5
POSTGRES_IMAGE_REPOSITORY=ghcr.io/cpfarhood/truenas-maas-app/postgres
POSTGRES_IMAGE_TAG=15
```

Then deploy (no build required!):
```bash
docker compose pull  # Pull pre-built images (~1GB total)
docker compose up -d
```

### Option 2: Edit compose.yaml Directly

Comment out the `build` sections and use `image` only:

```yaml
services:
  postgres:
    # build:
    #   context: .
    #   dockerfile: docker/postgres.Dockerfile
    image: ghcr.io/cpfarhood/truenas-maas-app/postgres:15
    # ... rest of configuration

  maas:
    # build:
    #   context: .
    #   dockerfile: Dockerfile
    image: ghcr.io/cpfarhood/truenas-maas-app/maas:3.5
    # ... rest of configuration
```

## Available Tags

### MAAS Image Tags
- `latest` - Latest build from main branch
- `3.5` - MAAS version 3.5 (recommended)
- `main` - Latest commit to main branch
- `vX.Y.Z` - Semantic version tags (e.g., v1.0.0)

### PostgreSQL Image Tags
- `latest` - Latest build from main branch
- `15` - PostgreSQL version 15 (recommended)
- `main` - Latest commit to main branch

## Benefits of Pre-built Images

✅ **Faster deployment** - No 15-20 minute build time
✅ **Consistent builds** - Same image for everyone
✅ **CI/CD tested** - Built and validated in GitHub Actions
✅ **Automated updates** - New images on every commit
✅ **Cached layers** - Efficient downloads
✅ **TrueNAS optimized** - Built with uid/gid 568

## Image Details

### Image Sizes
- MAAS: ~800 MB (compressed: ~300 MB)
- PostgreSQL: ~200 MB (compressed: ~70 MB)
- **Total Download**: ~370 MB compressed

### Build Information
- Platform: linux/amd64
- Base Images:
  - MAAS: Ubuntu 22.04 LTS
  - PostgreSQL: postgres:15-alpine
- Built on: GitHub Actions
- Registry: GitHub Container Registry (ghcr.io)

## Viewing Available Images

Visit the GitHub Container Registry to see all available images and tags:
https://github.com/cpfarhood/truenas-maas-app/pkgs/container/

## Pulling Images Manually

```bash
# Pull MAAS image
docker pull ghcr.io/cpfarhood/truenas-maas-app/maas:3.5

# Pull PostgreSQL image
docker pull ghcr.io/cpfarhood/truenas-maas-app/postgres:15

# View local images
docker images | grep truenas-maas-app
```

## Using with Docker Compose

### Pull and Deploy
```bash
# Pull latest images
docker compose pull

# Start services
docker compose up -d

# View logs
docker compose logs -f
```

### Update to Latest
```bash
# Pull newest images
docker compose pull

# Recreate containers with new images
docker compose up -d
```

## Security

All images are:
- ✅ Built from official base images
- ✅ Run as non-root user (uid/gid 568)
- ✅ Built in GitHub Actions (transparent build process)
- ✅ Signed by GitHub
- ✅ Scanned for vulnerabilities (planned)

## Image Build Process

Images are automatically built when:
1. **Push to main branch** - Triggers image build and push
2. **New tag/release** - Creates versioned images
3. **Manual workflow dispatch** - Can be triggered manually

Build process:
1. Checkout code
2. Set up Docker Buildx
3. Log in to GitHub Container Registry
4. Extract metadata (tags, labels)
5. Build multi-platform images
6. Push to registry
7. Cache layers for faster future builds

## Comparison: Pre-built vs Local Build

| Aspect | Pre-built Images | Local Build |
|--------|-----------------|-------------|
| **Initial Setup Time** | ~5 minutes | ~20-25 minutes |
| **Download Size** | ~370 MB | ~600 MB (packages) |
| **Disk Space** | ~1 GB | ~1 GB + build cache |
| **Updates** | `docker compose pull` | `docker compose build` |
| **Consistency** | ✅ Same for everyone | ⚠️ Varies by build time |
| **Customization** | ❌ Limited | ✅ Full control |
| **Best For** | Production, quick testing | Development, customization |

## Switching Between Build Methods

### From Local Build → Pre-built Images

1. Update `.env`:
   ```bash
   IMAGE_REPOSITORY=ghcr.io/cpfarhood/truenas-maas-app/maas
   POSTGRES_IMAGE_REPOSITORY=ghcr.io/cpfarhood/truenas-maas-app/postgres
   ```

2. Pull and restart:
   ```bash
   docker compose pull
   docker compose up -d
   ```

### From Pre-built → Local Build

1. Update `.env`:
   ```bash
   IMAGE_REPOSITORY=truenas-maas
   POSTGRES_IMAGE_REPOSITORY=truenas-maas-postgres
   ```

2. Build and restart:
   ```bash
   docker compose build
   docker compose up -d
   ```

## Troubleshooting

### Authentication Required Error
If you get authentication errors pulling from ghcr.io, the images may be private. This should not happen as images are public, but if it does:

```bash
# Log in to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

### Image Not Found
If the image doesn't exist yet (first time setup):
1. Wait for GitHub Actions to complete (check Actions tab in repository)
2. Or build locally first time: `docker compose build`

### Old Image Cached
If you're not getting the latest image:
```bash
docker compose pull --no-cache
docker compose down
docker compose up -d
```

## Image Verification

Verify you're using pre-built images:
```bash
# Check image sources
docker inspect maas-region | grep -A 5 "Image"
docker inspect maas-postgres | grep -A 5 "Image"

# Should show: ghcr.io/cpfarhood/truenas-maas-app/...
```

## FAQ

**Q: Do I need to build images locally?**
A: No! You can use pre-built images from GitHub Container Registry.

**Q: How often are images updated?**
A: On every commit to main branch and on tagged releases.

**Q: Can I use my own custom builds?**
A: Yes, just keep the default `build` sections in compose.yaml.

**Q: Are pre-built images secure?**
A: Yes, they're built in GitHub Actions with transparent build logs.

**Q: What if I need to customize the Dockerfile?**
A: Use local builds by keeping the `build` configuration.

**Q: Do pre-built images work on ARM (Apple Silicon)?**
A: Currently only amd64 is supported. ARM builds planned for future.

## Next Steps

- [Installation Guide](README.md#installation)
- [Docker Compose Documentation](DOCKER-COMPOSE-README.md)
- [Build Guide](BUILD-GUIDE.md) (for local builds)
