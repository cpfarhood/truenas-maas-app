# Agent Team Recommendations for MAAS TrueNAS App Project

## Revision History

**Version 2.0 (2026-02-12)** - Critical Re-evaluation
- **Context**: Re-analyzed after TrueNAS 25.10+ targeting clarification
- **Key Change**: REMOVED kubernetes-flux-specialist (not needed for Docker Compose app)
- **API Focus**: Added TrueNAS JSON-RPC 2.0 WebSocket expertise requirement
- **Clarity**: Distinguished development environment (K8s/Flux) from app deployment (Docker Compose)

**Version 1.0 (Initial)** - Original Analysis
- Initial agent team recommendations
- Included kubernetes-flux-specialist based on CLAUDE.md confusion

---

## Executive Summary

After re-evaluation with TrueNAS 25.10+ requirements, this document provides updated agent recommendations for building the MAAS integration app. **Critical change**: This is a **TrueNAS Docker Compose application**, NOT a Kubernetes application, despite the development environment using Kubernetes/Flux.

**Updated Team Composition:**
- **Keep**: 4 of 6 existing agents (removed agent-installer, prompt-engineer)
- **Remove from v1.0**: kubernetes-flux-specialist (not needed for Docker Compose app)
- **Add**: 8 new specialized agents (down from 9)

**Final Optimal Team: 12 agents** (down from 13 in v1.0)

---

## Critical Project Clarification

### What This Project Actually Is

**TrueNAS MAAS App:**
- **Deployment Model**: Docker Compose running on TrueNAS 25.10+
- **Container Runtime**: Native TrueNAS Docker Compose integration
- **API**: JSON-RPC 2.0 over WebSocket (if TrueNAS integration needed)
- **Not Kubernetes**: This app does NOT run on Kubernetes

**Development Environment (Separate):**
- **Developer Workflow**: Uses Kubernetes + Flux for GitOps (optional)
- **MCP Servers**: Kubernetes/Flux tools available for development/testing
- **Not the App**: These are development tools, not the app deployment model

**Why This Matters:**
The original recommendation included kubernetes-flux-specialist based on CLAUDE.md stating "uses Kubernetes with Flux." This was misleading - the K8s/Flux setup is for the development workflow, NOT for the MAAS app itself. The MAAS app is a Docker Compose application that runs directly on TrueNAS.

---

## Target Version Requirements

**TrueNAS 25.10+ Specific Considerations:**

### 1. API Requirements
- **JSON-RPC 2.0 WebSocket API**: Primary interface (if TrueNAS integration used)
  - Endpoint: `ws://truenas-host/websocket`
  - Authentication: API keys or session tokens
- **REST API**: DEPRECATED (25.04+), REMOVED in 26.04
  - **DO NOT USE** REST API in any new code
  - Daily alerts for REST API usage in 25.10.1+

### 2. Docker Compose Features (25.10+)
- Container registry mirror support
- Extended service timeout (960 seconds)
- `services:` key required in compose.yaml
- Better YAML validation and error reporting

### 3. Agent Impact
Any agent working with TrueNAS API must:
- Use JSON-RPC 2.0 over WebSocket (not REST)
- Understand TrueNAS 25.10+ API authentication
- Avoid deprecated REST endpoints
- Implement WebSocket connection handling

---

## Current Agent Analysis

### Agents to KEEP (4)

#### 1. **code-reviewer** (Opus)
**Status**: KEEP - Critical

**Why Keep**: Essential for Docker Compose security, Python API code quality, and shell script validation.

**TrueNAS 25.10+ Relevance**:
- Review Docker Compose for 25.10+ best practices
- Verify no REST API usage (deprecated)
- Check JSON-RPC 2.0 WebSocket implementation
- Validate security settings (non-root, capabilities)

**Key Responsibilities**:
- Docker Compose security review
- Python API client code review
- Shell script error handling validation
- YAML configuration correctness
- Container security best practices
- TrueNAS 25.10+ compatibility checks

---

#### 2. **technical-writer** (Haiku)
**Status**: KEEP - Essential

**Why Keep**: User-facing documentation is critical for TrueNAS app adoption.

**TrueNAS 25.10+ Relevance**:
- Document TrueNAS 25.10+ specific requirements
- Explain JSON-RPC API vs deprecated REST API
- Write installation guides for 25.10+ features
- Create troubleshooting guides for 25.10+ issues

**Key Responsibilities**:
- README.md and app-readme.md
- Installation guides for TrueNAS 25.10+
- User-friendly configuration documentation
- Troubleshooting guides
- Post-installation setup instructions

---

#### 3. **documentation-engineer** (Haiku)
**Status**: KEEP - Important

**Why Keep**: Developer documentation for API integration and automation scripts.

**TrueNAS 25.10+ Relevance**:
- Document JSON-RPC 2.0 WebSocket API integration
- Provide migration notes from REST to WebSocket
- Create code examples for 25.10+ API

**Key Responsibilities**:
- API reference documentation (MAAS + TrueNAS)
- Developer integration guides
- Code examples with tests
- Architecture documentation
- Contributing guidelines

**Distinction from technical-writer**:
- technical-writer: End users, admins (installation, usage)
- documentation-engineer: Developers, API consumers (integration, automation)

---

#### 4. **agent-organizer** (Sonnet)
**Status**: KEEP - Valuable

**Why Keep**: Coordinates multi-agent workflows and optimizes team efficiency.

**Key Responsibilities**:
- Coordinate agent assignments across project phases
- Optimize agent collaboration patterns
- Monitor team performance
- Resolve agent conflicts or overlaps
- Adjust agent allocation as needed

---

### Agents to REMOVE (2)

#### 1. **agent-installer** (Haiku)
**Status**: REMOVE

**Why Remove**: Only needed for initial agent setup. Once team is assembled, this agent provides no ongoing value for MAAS app development.

**Reasoning**: Agent discovery and installation is a one-time setup activity, not a core project requirement.

---

#### 2. **prompt-engineer** (Sonnet)
**Status**: REMOVE

**Why Remove**: This project builds infrastructure (Docker Compose + APIs), not LLM applications. No prompt optimization or AI model work required.

**Reasoning**: MAAS app focuses on bare metal provisioning and TrueNAS integration, not LLM features.

---

### Agent REMOVED from v1.0 Recommendations

#### **kubernetes-flux-specialist** (Sonnet)
**Status**: REMOVED in v2.0

**Why Removed**: **This is the critical correction from v1.0.**

**Original Reasoning (v1.0)**: "Repository uses Kubernetes with Flux for GitOps deployments (per CLAUDE.md)"

**Corrected Analysis (v2.0)**:
- The MAAS app is a **TrueNAS Docker Compose application**
- It does NOT run on Kubernetes or use Flux
- The K8s/Flux MCP servers are for optional development/testing workflows
- TrueNAS 25.10+ uses Docker Compose as the native container runtime
- The app is deployed via TrueNAS app catalog, not K8s manifests

**What CLAUDE.md Got Wrong**:
```markdown
# CLAUDE.md (INCORRECT)
"The project uses Kubernetes with Flux for GitOps-based deployments"
```

**Reality**:
```markdown
# Actual Project (CORRECT)
"TrueNAS 25.10+ app using Docker Compose as native container runtime"
```

**Developer Environment vs App Deployment**:
- **Developer Environment** (optional): May use K8s/Flux for testing
- **App Deployment** (production): Docker Compose on TrueNAS

**Conclusion**: kubernetes-flux-specialist is NOT needed for building a TrueNAS Docker Compose app.

---

## Agents to ADD (8 New Agents)

### Development & Implementation Agents

#### 1. **docker-compose-architect** (Sonnet)
**Source**: Custom (TrueNAS-specific)

**Description**: Expert in Docker Compose for TrueNAS 25.10+ with deep knowledge of native TrueNAS integration, Docker Compose extensions, and container orchestration.

**Why Needed**: TrueNAS 25.10+ uses Docker Compose as the primary container runtime. This agent must understand TrueNAS-specific compose.yaml requirements, extensions, and best practices.

**TrueNAS 25.10+ Expertise**:
- TrueNAS compose.yaml structure (requires `services:` key)
- Registry mirror configuration
- Extended service timeout (960 seconds)
- Volume mount best practices (no ixVolumes in production)
- Network modes (bridge vs host)
- Security context (non-root, capabilities)

**Key Responsibilities**:
- Design Docker Compose architecture for TrueNAS 25.10+
- Configure multi-container networking (MAAS + PostgreSQL)
- Implement volume mount strategies with proper permissions
- Set up health checks and service dependencies
- Optimize container security (non-root, capability restrictions)
- Handle bridge vs host networking for PXE boot scenarios

**Phase Activities**:
- Phase 1: Create compose.yaml with TrueNAS 25.10+ features
- Phase 1: Design volume management strategy
- Phase 1: Implement health checks
- Phase 4: Performance optimization

**Tools**: Read, Write, Edit, Bash, Glob

**Model**: Sonnet

---

#### 2. **python-api-developer** (Sonnet)
**Source**: Adaptation from backend-developer

**Description**: Expert Python developer specializing in REST API clients (MAAS) and JSON-RPC 2.0 WebSocket clients (TrueNAS), async programming, and automation scripts.

**Why Needed**: Project requires:
1. MAAS REST API client implementation
2. TrueNAS JSON-RPC 2.0 WebSocket client (if TrueNAS integration used)
3. Automation scripts for provisioning workflows
4. Integration tests

**TrueNAS 25.10+ API Expertise**:
- **MUST USE**: JSON-RPC 2.0 over WebSocket
- **MUST NOT USE**: REST API (deprecated, removed in 26.04)
- WebSocket connection handling (`websockets` library)
- JSON-RPC 2.0 protocol (request/response format)
- API authentication (API keys, session tokens)
- Error handling for WebSocket disconnections

**Key Responsibilities**:
- Implement MAAS REST API client wrapper (python-libmaas or custom)
- Implement TrueNAS JSON-RPC 2.0 WebSocket client (if needed)
- Create automation scripts (commissioning, deployment, etc.)
- Develop Python-based integration tests
- Handle async/await patterns correctly
- Implement proper error handling and retries
- Ensure zero deprecated API usage

**Critical TrueNAS API Patterns**:
```python
# CORRECT (JSON-RPC 2.0 WebSocket)
import websocket
import json

ws = websocket.create_connection("ws://truenas/websocket")
request = {
    "jsonrpc": "2.0",
    "method": "system.version",
    "params": [],
    "id": 1
}
ws.send(json.dumps(request))
response = json.loads(ws.recv())

# WRONG (Deprecated REST API - DO NOT USE)
import requests
response = requests.get("http://truenas/api/v2.0/system/version")
```

**Phase Activities**:
- Phase 3: Build MAAS REST API client library
- Phase 3: Build TrueNAS JSON-RPC 2.0 client (if needed)
- Phase 3: Create automation scripts
- Phase 4: Develop integration tests
- Phase 4: Verify no REST API deprecation warnings

**Tools**: Read, Write, Edit, Bash, Grep, Glob

**Model**: Sonnet

---

#### 3. **truenas-yaml-specialist** (Haiku)
**Source**: Custom (TrueNAS 25.10+ specific)

**Description**: Expert in TrueNAS 25.10+ app metadata (app.yaml), configuration UI (questions.yaml), and Docker Compose YAML with TrueNAS extensions.

**Why Needed**: TrueNAS 25.10+ has specific YAML requirements and formatting that differ from generic Docker Compose. This specialist ensures compliance with TrueNAS app catalog standards.

**TrueNAS 25.10+ YAML Expertise**:
- app.yaml structure and validation
- `min_scale_version: 25.10.0` enforcement
- questions.yaml schema types (hostpath, string, int, etc.)
- Docker Compose with TrueNAS extensions
- `services:` key requirement (25.10+)
- Variable substitution patterns: `${VAR:-default}`

**Key Responsibilities**:
- Create app.yaml with complete metadata
- Set `min_scale_version: 25.10.0` requirement
- Design questions.yaml configuration UI
- Validate YAML syntax and TrueNAS compatibility
- Implement proper variable substitution
- Ensure catalog submission requirements met

**Critical Fields**:
```yaml
# app.yaml
name: maas
min_scale_version: 25.10.0  # Enforce TrueNAS 25.10+
train: community
run_as_context:
  - uid: 1000  # Non-root requirement
    gid: 1000

# compose.yaml
name: maas
services:  # REQUIRED in TrueNAS 25.10+
  maas:
    image: ${IMAGE_REPOSITORY}:${IMAGE_TAG}
    user: "${RUN_AS_USER:-1000}:${RUN_AS_GROUP:-1000}"
```

**Phase Activities**:
- Phase 1: Create app.yaml with 25.10+ requirements
- Phase 2: Design questions.yaml
- All phases: YAML validation and compliance

**Tools**: Read, Write, Edit, Glob, Grep

**Model**: Haiku

---

#### 4. **shell-script-engineer** (Haiku)
**Source**: Adaptation from devops agents

**Description**: Production-grade shell scripting specialist for initialization, backup, and operational scripts.

**Why Needed**: TrueNAS apps require initialization scripts (first-run setup), backup/restore procedures, and operational automation.

**Key Responsibilities**:
- Create init-maas.sh initialization script
- Implement backup/restore scripts
- Develop operational helper scripts
- Handle error conditions properly (set -euo pipefail)
- Ensure POSIX compatibility
- Validate user input and environment variables

**Critical Patterns**:
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined var, pipe failure

# Example: MAAS initialization
if [ ! -f /etc/maas/configured ]; then
  maas createadmin --username="${MAAS_ADMIN_USERNAME}" \
                   --password="${MAAS_ADMIN_PASSWORD}" \
                   --email="${MAAS_ADMIN_EMAIL}"
  touch /etc/maas/configured
fi
```

**Phase Activities**:
- Phase 1: Create initialization script
- Phase 3: Implement backup/restore scripts
- Phase 3: Create automation helpers

**Tools**: Read, Write, Edit, Bash

**Model**: Haiku

---

### Testing & Quality Agents

#### 5. **integration-test-engineer** (Sonnet)
**Source**: Adaptation from testing agents

**Description**: Integration testing specialist for containerized applications with Docker-based test environments.

**Why Needed**: Comprehensive testing of Docker Compose deployment, MAAS workflows, API integration, and data persistence on TrueNAS 25.10+.

**Key Responsibilities**:
- Design integration test framework
- Implement Docker-based test environments
- Create end-to-end workflow tests
- Test container orchestration
- Verify MAAS API functionality
- Test data persistence across restarts
- Validate TrueNAS 25.10+ compatibility

**Test Scenarios**:
```python
@pytest.mark.asyncio
async def test_maas_deployment_workflow():
    """Test full machine provisioning workflow"""
    # 1. Container health
    assert container_healthy("maas")
    assert container_healthy("postgres")

    # 2. MAAS API accessible
    client = MAASClient(...)
    machines = await client.machines.list()

    # 3. Provisioning workflow
    machine = machines[0]
    await machine.commission()
    await machine.deploy(distro_series="jammy")
    assert machine.status_name == "Deployed"
```

**Phase Activities**:
- Phase 3: Design test framework
- Phase 4: Implement integration tests
- Phase 4: Execute test suite
- Phase 4: TrueNAS 25.10+ compatibility validation

**Tools**: Read, Write, Edit, Bash, Glob

**Model**: Sonnet

---

#### 6. **security-auditor** (Opus)
**Source**: Adaptation from security agents

**Description**: Security specialist for container security, secrets management, and infrastructure hardening.

**Why Needed**: Production TrueNAS apps require security audit covering container security, non-root execution, secrets management, network isolation, and API security.

**Key Responsibilities**:
- Audit Docker Compose security settings
- Review secrets management (no hardcoded passwords)
- Verify non-root execution (uid/gid 568)
- Check capability restrictions (NET_ADMIN, NET_RAW only)
- Test network isolation (bridge vs host)
- Review API authentication (MAAS, TrueNAS)
- Identify vulnerability patterns

**Security Checklist**:
- [ ] Containers run as non-root user
- [ ] No hardcoded credentials in compose.yaml
- [ ] Capabilities limited to minimum required
- [ ] Volume mounts have appropriate permissions
- [ ] API keys stored securely (environment variables)
- [ ] Network isolation tested
- [ ] TLS/HTTPS configuration validated

**Phase Activities**:
- Phase 1: Initial security review
- Phase 4: Comprehensive security audit
- Phase 4: Penetration testing recommendations

**Tools**: Read, Bash, Grep, Glob

**Model**: Opus

---

### Operations & Support Agents

#### 7. **monitoring-observability-engineer** (Haiku)
**Source**: Adaptation from devops agents

**Description**: Observability specialist for logging, monitoring, health checks, and alerting in containerized environments.

**Why Needed**: Production TrueNAS apps need health monitoring, log aggregation, and operational visibility.

**Key Responsibilities**:
- Design monitoring strategy
- Configure Docker health checks
- Implement log aggregation
- Set up alerting rules
- Create operational dashboards (optional)
- Define SLIs/SLOs

**Health Check Patterns**:
```yaml
services:
  maas:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5240/MAAS/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

**Phase Activities**:
- Phase 3: Design monitoring architecture
- Phase 3: Implement logging
- Phase 4: Set up dashboards (optional)

**Tools**: Read, Write, Edit, Bash

**Model**: Haiku

---

#### 8. **truenas-catalog-specialist** (Sonnet)
**Source**: Custom (TrueNAS-specific)

**Description**: Expert in TrueNAS app catalog submission, GitHub PR management, and community engagement for TrueNAS apps.

**Why Needed**: Getting the MAAS app into the TrueNAS catalog requires understanding catalog structure, submission requirements, review process, and community standards.

**TrueNAS Catalog Expertise**:
- TrueNAS apps repository structure (ix-dev/train/app-name/)
- Catalog trains (stable, community, enterprise, test)
- App submission requirements and validation
- GitHub PR process for truenas/apps
- Community review standards
- Version management and updates

**Key Responsibilities**:
- Prepare catalog submission package
- Create GitHub release with changelog
- Submit PR to truenas/apps repository
- Address review comments
- Manage community feedback
- Handle app updates and versioning

**Submission Checklist**:
- [ ] app.yaml complete with all required fields
- [ ] compose.yaml validated for TrueNAS 25.10+
- [ ] Icon and screenshots provided (512x512, 1280x720)
- [ ] Documentation complete (README, app-readme)
- [ ] Version numbers follow semantic versioning
- [ ] Security context configured properly
- [ ] Test installation on fresh TrueNAS 25.10 instance

**Phase Activities**:
- Phase 5: Prepare release package
- Phase 5: Submit catalog PR
- Phase 5: Community engagement
- Ongoing: Issue management and updates

**Tools**: Read, Write, Edit, mcp__github (full suite)

**Model**: Sonnet

---

## Recommended Agent Team Structure

### Final Optimal Team (12 Agents)

**Tier 1 - Core Development (4 agents)**
1. **docker-compose-architect** (Sonnet) - TrueNAS Docker Compose expertise
2. **python-api-developer** (Sonnet) - MAAS + TrueNAS API clients
3. **truenas-yaml-specialist** (Haiku) - app.yaml, questions.yaml, compose.yaml
4. **shell-script-engineer** (Haiku) - Init scripts, backup/restore

**Tier 2 - Quality Assurance (3 agents)**
5. **code-reviewer** (Opus) - Code quality & security
6. **integration-test-engineer** (Sonnet) - Integration testing
7. **security-auditor** (Opus) - Security audit

**Tier 3 - Documentation (2 agents)**
8. **technical-writer** (Haiku) - User documentation
9. **documentation-engineer** (Haiku) - Developer documentation

**Tier 4 - Operations (2 agents)**
10. **monitoring-observability-engineer** (Haiku) - Logging & monitoring
11. **truenas-catalog-specialist** (Sonnet) - Catalog submission & community

**Tier 5 - Coordination (1 agent)**
12. **agent-organizer** (Sonnet) - Team coordination

---

## Key Changes from v1.0

### Removed Agents
1. **kubernetes-flux-specialist** - NOT NEEDED
   - **Reason**: This is a Docker Compose app, not a Kubernetes app
   - **Confusion**: CLAUDE.md incorrectly stated "uses Kubernetes with Flux"
   - **Reality**: K8s/Flux are optional development tools, not app deployment

### Renamed/Refocused Agents
1. **docker-architect** → **docker-compose-architect**
   - **Focus**: TrueNAS 25.10+ specific Docker Compose
   - **Not**: Generic Docker or Kubernetes

2. **python-developer** → **python-api-developer**
   - **Added**: Explicit TrueNAS JSON-RPC 2.0 WebSocket expertise
   - **Critical**: Must avoid deprecated REST API

3. **yaml-config-specialist** → **truenas-yaml-specialist**
   - **Focus**: TrueNAS 25.10+ specific YAML (app.yaml, questions.yaml)
   - **Not**: Generic YAML or Kubernetes manifests

4. **github-release-manager** → **truenas-catalog-specialist**
   - **Expanded**: TrueNAS catalog submission expertise
   - **Not**: Just generic GitHub release management

5. **monitoring-engineer** → **monitoring-observability-engineer**
   - **Clarity**: Broader observability focus (logging, monitoring, health)

---

## TrueNAS 25.10+ Specific Agent Requirements

### Every Agent Must Understand
1. This is a **TrueNAS Docker Compose app** (NOT Kubernetes)
2. Target version is **TrueNAS 25.10+** (NOT 24.10)
3. Use **JSON-RPC 2.0 WebSocket API** (NOT REST API)
4. Docker Compose requires **`services:` key** (25.10+ requirement)
5. Run containers as **non-root** (uid/gid 568)

### Critical API Requirement
Any agent working with TrueNAS API:
- **MUST USE**: JSON-RPC 2.0 over WebSocket
- **MUST NOT USE**: REST API (deprecated, removed in 26.04)
- **MUST VALIDATE**: No REST API deprecation warnings

### Critical Docker Compose Requirements
Any agent working with compose.yaml:
- **MUST INCLUDE**: `services:` top-level key
- **MUST SUPPORT**: Variable substitution (`${VAR:-default}`)
- **MUST CONFIGURE**: Health checks for services with dependencies
- **MUST SET**: Non-root user (`user: "568:568"`)

---

## Agent Workflow Coordination

### Phase 1: Core Infrastructure (Week 1)

**Primary Agents**:
- docker-compose-architect: Design Docker Compose for TrueNAS 25.10+
- truenas-yaml-specialist: Create app.yaml with min_scale_version
- shell-script-engineer: Build initialization scripts
- code-reviewer: Review security and quality

**Deliverables**:
- compose.yaml with TrueNAS 25.10+ features
- app.yaml with correct metadata
- init-maas.sh initialization script
- Working deployment on TrueNAS 25.10+

---

### Phase 2: Configuration & UI (Week 2)

**Primary Agents**:
- truenas-yaml-specialist: Create questions.yaml
- technical-writer: Write installation guide
- code-reviewer: Review configurations

**Deliverables**:
- questions.yaml with user-friendly configuration
- Installation documentation
- Configuration guide

---

### Phase 3: Integration & Automation (Week 3)

**Primary Agents**:
- python-api-developer: Build MAAS + TrueNAS API clients
- shell-script-engineer: Create automation scripts
- monitoring-observability-engineer: Set up logging
- documentation-engineer: API documentation

**Deliverables**:
- MAAS REST API client library
- TrueNAS JSON-RPC 2.0 client (if needed)
- Automation scripts (provisioning workflows)
- Backup/restore scripts
- API documentation

---

### Phase 4: Testing & Documentation (Week 4)

**Primary Agents**:
- integration-test-engineer: Run comprehensive tests
- security-auditor: Perform security audit
- technical-writer: Complete user documentation
- documentation-engineer: Finalize developer docs
- code-reviewer: Final quality review

**Deliverables**:
- Integration test suite (passing)
- Security audit report (no critical issues)
- Complete user documentation
- Complete developer documentation
- TrueNAS 25.10+ compatibility validated

---

### Phase 5: Community Release (Week 5)

**Primary Agents**:
- truenas-catalog-specialist: Prepare and submit release
- technical-writer: Create announcement materials
- agent-organizer: Coordinate launch activities

**Deliverables**:
- GitHub release with changelog
- PR to truenas/apps repository
- Community announcement
- Support documentation

---

## Agent Communication Patterns

### Sequential Handoffs
- docker-compose-architect → truenas-yaml-specialist → code-reviewer
- Pattern: Design → Configuration → Validation

### Parallel Execution
- python-api-developer + shell-script-engineer + monitoring-observability-engineer
- Pattern: Independent development streams

### Review Gates
- All code → code-reviewer → Approval
- All security-critical → security-auditor → Approval
- Pattern: Quality gates before proceeding

### Documentation Sync
- Feature completion → technical-writer + documentation-engineer
- Pattern: Documentation follows implementation

### Meta-Coordination
- agent-organizer monitors all agents
- Pattern: Orchestrator oversight and optimization

---

## Success Metrics

### Team Performance KPIs

**Development Velocity**:
- Phase completion on schedule (target: 100%)
- Code review turnaround < 24 hours
- Bug fix time < 48 hours

**Quality Metrics**:
- Zero critical security issues
- Code coverage > 80%
- Documentation completeness > 95%
- All integration tests passing
- No TrueNAS REST API deprecation warnings

**TrueNAS 25.10+ Compliance**:
- App installs on fresh TrueNAS 25.10 instance
- No version compatibility warnings
- All 25.10+ features utilized correctly
- JSON-RPC API used (if TrueNAS integration)
- No deprecated REST API calls

**Collaboration Metrics**:
- Agent handoff success rate > 95%
- Inter-agent communication clarity
- Minimal duplicate work
- Efficient resource utilization

**Project Outcomes**:
- App accepted in TrueNAS catalog
- Positive community feedback
- Zero critical bugs in first release

---

## Resource Optimization

### Model Selection Rationale

**Opus Agents (2)** - High-complexity analysis:
- code-reviewer: Complex code and security analysis
- security-auditor: Critical security review

**Sonnet Agents (6)** - Core development and coordination:
- docker-compose-architect: Complex Docker Compose design
- python-api-developer: API client implementation
- integration-test-engineer: Complex test scenarios
- truenas-catalog-specialist: Catalog submission coordination
- agent-organizer: Team coordination and optimization

**Haiku Agents (4)** - Well-defined structured tasks:
- truenas-yaml-specialist: Structured YAML configuration
- shell-script-engineer: Script writing with clear patterns
- technical-writer: User documentation
- documentation-engineer: Developer documentation
- monitoring-observability-engineer: Observability setup

**Cost Optimization Strategy**:
- Use Haiku for template-driven, structured work
- Use Sonnet for complex implementation and coordination
- Use Opus only for critical quality and security gates
- Total: 2 Opus + 6 Sonnet + 4 Haiku = 12 agents

---

## Risk Mitigation

### Critical Risks Addressed

**Risk 1: Kubernetes Confusion**
- **Mitigation**: Removed kubernetes-flux-specialist
- **Clarification**: This is a Docker Compose app, not Kubernetes
- **Impact**: Prevents misdirected development effort

**Risk 2: REST API Usage**
- **Mitigation**: python-api-developer explicitly trained on JSON-RPC 2.0
- **Validation**: code-reviewer checks for deprecated API usage
- **Impact**: Ensures TrueNAS 26.04+ compatibility

**Risk 3: TrueNAS 24.10 Compatibility**
- **Mitigation**: truenas-yaml-specialist enforces min_scale_version: 25.10.0
- **Validation**: Testing on TrueNAS 25.10+ only
- **Impact**: Avoids future migration pain

**Risk 4: Docker Compose Format**
- **Mitigation**: docker-compose-architect knows TrueNAS 25.10+ requirements
- **Validation**: truenas-yaml-specialist validates `services:` key presence
- **Impact**: Ensures app installs correctly

---

## Agent Onboarding Sequence

### Recommended Installation Order

**Day 1: Foundation**
1. agent-organizer (coordinate team)
2. docker-compose-architect (establish architecture)
3. code-reviewer (enable quality gates)

**Day 2: Core Development**
4. truenas-yaml-specialist (app.yaml, compose.yaml)
5. shell-script-engineer (initialization scripts)
6. python-api-developer (API client skeleton)

**Day 3: Quality & Documentation**
7. security-auditor (security reviews)
8. integration-test-engineer (test framework)
9. technical-writer (user documentation)
10. documentation-engineer (developer documentation)

**Day 4: Operations & Release**
11. monitoring-observability-engineer (observability setup)
12. truenas-catalog-specialist (catalog preparation)

---

## What Changed from v1.0

### Critical Corrections

**1. Removed kubernetes-flux-specialist**
- **v1.0 Reasoning**: "Repository uses Kubernetes with Flux for GitOps"
- **v2.0 Correction**: MAAS app is Docker Compose, not Kubernetes
- **Root Cause**: CLAUDE.md was misleading about deployment model
- **Impact**: Prevents wasted effort on unnecessary K8s expertise

**2. Clarified Docker Compose Focus**
- **v1.0**: docker-architect (generic)
- **v2.0**: docker-compose-architect (TrueNAS-specific)
- **Reason**: TrueNAS 25.10+ has specific Docker Compose requirements

**3. Added TrueNAS API Expertise**
- **v1.0**: Generic Python developer
- **v2.0**: python-api-developer with JSON-RPC 2.0 expertise
- **Reason**: TrueNAS 25.10+ requires JSON-RPC, not REST API

**4. Added TrueNAS Catalog Specialist**
- **v1.0**: github-release-manager (generic)
- **v2.0**: truenas-catalog-specialist (TrueNAS-specific)
- **Reason**: Catalog submission has specific TrueNAS requirements

**5. Updated All Agent Descriptions**
- Added TrueNAS 25.10+ specific requirements
- Clarified JSON-RPC 2.0 vs deprecated REST API
- Emphasized Docker Compose (not Kubernetes)

---

## Conclusion

### Final Team Composition

**12 Optimal Agents** (down from 13 in v1.0):
- **Removed**: kubernetes-flux-specialist (not needed)
- **Kept**: 4 existing agents (code-reviewer, technical-writer, documentation-engineer, agent-organizer)
- **Added**: 8 new specialized agents with TrueNAS 25.10+ focus

### Key Success Factors

**Clarity on Deployment Model**:
- This is a TrueNAS Docker Compose app
- NOT a Kubernetes/Flux application
- K8s/Flux are optional development tools only

**TrueNAS 25.10+ Compliance**:
- All agents understand 25.10+ requirements
- JSON-RPC 2.0 API expertise (not REST)
- Docker Compose best practices for TrueNAS
- Catalog submission requirements

**Team Efficiency**:
- Clear role separation and coordination
- Built-in quality and security gates
- Appropriate model selection for cost optimization
- Strong documentation throughout development

**Project Confidence**:
- 5-week timeline achievable
- Parallel workstreams enabled
- Quality gates prevent downstream issues
- Community release prepared

This updated team eliminates confusion, focuses on actual requirements, and ensures TrueNAS 25.10+ compatibility throughout the project lifecycle.
