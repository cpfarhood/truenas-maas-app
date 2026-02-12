# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a TrueNAS application for MAAS (Metal as a Service) integration. This is a **Docker Compose application** that runs on TrueNAS 25.10+, NOT a Kubernetes application.

**Target TrueNAS Version: 25.10 and Later**

This application is specifically designed for TrueNAS 25.10 (Goldeye) and later versions. Key requirements:
- **Minimum Version**: TrueNAS 25.10.0
- **API**: JSON-RPC 2.0 over WebSocket (REST API deprecated, removed in 26.04)
- **Container Runtime**: Docker Compose with native TrueNAS integration
- **Do NOT use**: TrueNAS REST API (deprecated since 25.04)

## MCP Server Configuration

This repository is configured with the following MCP servers (in `.mcp.json`):
- **github**: GitHub API access for repository operations
- **kubernetes (local)**: Local Kubernetes cluster management (for optional development/testing workflows)
- **flux (local)**: Flux operator for GitOps workflows (for optional development/testing workflows)
- **playwright**: Browser automation for testing

**Note**: The Kubernetes and Flux MCP servers are for optional development workflows. The MAAS app itself is a TrueNAS Docker Compose application, not a Kubernetes deployment.

## Development Environment

### Prerequisites
- GitHub personal access token set as `CLAUDE_GITHUB_TOKEN` environment variable
- TrueNAS 25.10+ test environment (for app validation)
- Docker and Docker Compose (for local testing)
- Python 3.11+ (for MAAS API client development)
- Knowledge of JSON-RPC 2.0 WebSocket API (for TrueNAS integration if needed)

### API Version Requirements

**TrueNAS API (if integration needed):**
- **Use**: JSON-RPC 2.0 over WebSocket (`ws://truenas-host/websocket`)
- **Do NOT use**: REST API (deprecated in 25.04, removed in 26.04)
- **Authentication**: API keys or session tokens
- **Documentation**: [TrueNAS JSON-RPC API](https://api.truenas.com/v25.04/jsonrpc.html)

**Version Compatibility:**
- Targeting TrueNAS 25.10+ ensures compatibility with future versions (26.04+)
- Avoids REST API deprecation warnings and future breakage
- Leverages modern Docker Compose features in TrueNAS 25.10

## Repository Structure

This is a TrueNAS Docker Compose application with the following structure:
- **`ix-dev/`**: TrueNAS app catalog structure (future location for app submission)
- **`app.yaml`**: TrueNAS app metadata
- **`compose.yaml`**: Docker Compose configuration
- **`questions.yaml`**: TrueNAS UI configuration (optional)
- **`.claude/agents/`**: Specialized agent definitions for development
- **`prompts/`**: Project prompts and documentation
- **`docs/`**: Additional documentation

## Available Agents

This repository includes 12 specialized agents in `.claude/agents/` for different aspects of development:

### Core Development (Sonnet/Opus)
1. **docker-compose-architect** (Sonnet) - Docker Compose architecture for TrueNAS 25.10+
2. **python-api-developer** (Sonnet) - MAAS API client and TrueNAS JSON-RPC 2.0 integration
3. **integration-test-engineer** (Sonnet) - Docker-based integration testing
4. **truenas-catalog-specialist** (Sonnet) - Catalog submission and release management

### Configuration & Scripting (Haiku)
5. **truenas-yaml-specialist** (Haiku) - app.yaml, compose.yaml, questions.yaml configuration
6. **shell-script-engineer** (Haiku) - Init scripts, backup/restore, health checks
7. **monitoring-observability-engineer** (Haiku) - Logging, metrics, health monitoring

### Quality Assurance (Opus/Haiku)
8. **code-reviewer** (Opus) - Code quality and security review
9. **security-auditor** (Opus) - Container security and vulnerability scanning

### Documentation (Haiku)
10. **technical-writer** (Haiku) - User-facing documentation (README, guides)
11. **documentation-engineer** (Haiku) - Developer documentation (API reference)

### Coordination (Sonnet)
12. **agent-organizer** (Sonnet) - Multi-agent team coordination

**Usage**: Use the Task tool with `subagent_type: "general-purpose"` and reference the specific agent by loading its prompt from `.claude/agents/<agent-name>.md`.

## TrueNAS App Development

### Docker Compose Requirements
- All containers must run as non-root (uid/gid 1000)
- Include `services:` key in compose.yaml (TrueNAS 25.10+ requirement)
- Use host path volumes (NOT ixVolumes): `/mnt/poolname/appname/`
- Implement health checks for all services
- Configure restart policies appropriately
- Use bridge network mode (or host if PXE/DHCP required)

### YAML Configuration Files
- **app.yaml**: App metadata with `min_scale_version: 25.10.0`
- **compose.yaml**: Docker Compose with all TrueNAS requirements
- **questions.yaml**: Optional UI configuration for user inputs
- **app-readme.md**: Catalog description (shown in TrueNAS UI)

### Testing
- Test locally with Docker Compose
- Validate on TrueNAS 25.10+ test environment
- Use integration-test-engineer agent for automated testing
- Use Playwright MCP server for browser-based integration testing if needed

## Best Practices

### TrueNAS App Development
1. Follow TrueNAS 25.10+ requirements strictly
2. Never use deprecated REST API (use JSON-RPC 2.0 if needed)
3. Run all containers as non-root for security
4. Implement comprehensive health checks
5. Document all configuration options clearly
6. Test thoroughly before catalog submission

### Version Control
- Commit all configuration changes
- Use semantic versioning for releases
- Maintain detailed CHANGELOG.md
- Tag releases appropriately

### Documentation
- Keep README.md current with installation steps
- Update app-readme.md for catalog display
- Document troubleshooting steps
- Include example configurations
