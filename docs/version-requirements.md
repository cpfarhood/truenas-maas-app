# TrueNAS Version Requirements

## Minimum Version

**TrueNAS 25.10.0 (Goldeye) or Later**

This MAAS integration app requires TrueNAS 25.10.0 or later. Using earlier versions is not recommended and may result in compatibility issues, missing features, or future breakage.

## Why TrueNAS 25.10+?

### 1. API Modernization

**JSON-RPC 2.0 WebSocket API (Primary Interface)**
- TrueNAS 25.10+ provides a stable, versioned JSON-RPC 2.0 API over WebSocket
- Endpoint: `ws://truenas-host/websocket`
- Authentication: API keys or session-based tokens
- Full API reference: [TrueNAS JSON-RPC API v25.04](https://api.truenas.com/v25.04/jsonrpc.html)

**REST API Deprecation Timeline**
- **25.04**: REST API officially deprecated
- **25.10.1+**: Daily alerts for deprecated REST API endpoint usage
- **26.04**: REST API completely removed
- **Impact**: Applications using REST API will break in TrueNAS 26.04

**Why This Matters**:
By targeting 25.10+, this app:
- Avoids deprecated API warnings
- Ensures forward compatibility with TrueNAS 26.04+
- Uses the officially supported API interface
- Benefits from API improvements and versioning

**Sources:**
- [TrueNAS 25.10 Version Notes](https://www.truenas.com/docs/scale/25.10/gettingstarted/versionnotes/)
- [26.04 Development Notes](https://www.truenas.com/docs/scale/gettingstarted/versionnotes/)
- [Feature Deprecations](https://www.truenas.com/docs/scale/gettingstarted/deprecations/)

### 2. Docker Compose Improvements

**TrueNAS 25.10 Docker Compose Features:**

1. **Container Registry Mirrors**
   - Support for external container registry mirrors
   - Alternative sources for Docker images
   - Improved reliability and performance

2. **Extended Service Timeout**
   - Service timeout extended to 960 seconds (16 minutes)
   - Accommodates slower disk scenarios
   - Reduces deployment failures on HDD-based systems

3. **Custom App Validation**
   - Improved YAML validation (v1.2.14+)
   - Better upgrade detection for custom apps
   - Image version tracking and upgrade availability

4. **YAML Format Requirements**
   - `services:` key required for new stacks (25.10+)
   - Updated Docker Compose syntax support
   - Better error reporting for misconfigurations

**Sources:**
- [TrueNAS 25.10 Custom Apps Documentation](https://www.truenas.com/docs/scale/25.10/scaleuireference/apps/installcustomappscreens/)
- [TrueNAS Apps Reference](https://www.truenas.com/docs/scale/25.10/scaleuireference/apps/)

### 3. Breaking Changes from 24.10

**API Key Migration**
- Legacy API keys from TrueNAS 24.10 or earlier automatically migrate to `root`, `admin`, or `truenas_admin` accounts
- API keys created via API (not UI) with allow lists are revoked during upgrade
- **Action Required**: Regenerate API keys after upgrading from 24.10

**IDMAP Backend Removal**
- AUTORID IDMAP backend removed from Active Directory configuration
- Existing AUTORID configurations automatically migrate to RID
- Improves consistency across multi-server environments

**GPU Driver Changes**
- Switch to open GPU kernel drivers
- Legacy NVIDIA GPUs no longer supported:
  - Pascal architecture
  - Maxwell architecture
  - Volta architecture
- **Action Required**: Verify GPU compatibility if using GPU passthrough

**Sources:**
- [25.04 Version Notes](https://www.truenas.com/docs/scale/25.04/gettingstarted/scalereleasenotes/)
- [25.10 Version Notes](https://www.truenas.com/docs/scale/25.10/gettingstarted/versionnotes/)

## Version-Specific Features Used

This MAAS app leverages the following TrueNAS 25.10+ features:

### Docker Compose Configuration
```yaml
name: maas
services:  # Required in TrueNAS 25.10+
  maas:
    image: ${IMAGE_REPOSITORY}:${IMAGE_TAG}
    # ... configuration
```

### App Metadata (app.yaml)
```yaml
name: maas
min_scale_version: 25.10.0  # Enforces minimum version
```

### JSON-RPC API Integration (if used)
```python
import websocket
import json

# Connect to TrueNAS JSON-RPC API
ws = websocket.create_connection("ws://truenas-host/websocket")

# Authenticate
auth_request = {
    "jsonrpc": "2.0",
    "method": "auth.login",
    "params": ["username", "password"],
    "id": 1
}
ws.send(json.dumps(auth_request))
```

### Registry Mirror Support
- Ability to configure alternative container registries
- Fallback options for image pulls
- Improved deployment reliability

## Compatibility Considerations

### TrueNAS 24.10 (Not Recommended)

**Issues with 24.10:**
- No REST API deprecation warnings (silent breakage in 26.04)
- Missing Docker Compose improvements
- No registry mirror support
- Shorter service timeout (may cause deployment failures)
- Will require migration work when upgrading to 26.04

**If You Must Use 24.10:**
1. Be prepared for breaking changes in TrueNAS 26.04
2. Plan to migrate to JSON-RPC API before upgrading
3. Test thoroughly on 24.10 environment
4. Monitor for API-related issues

### TrueNAS 25.04 (Minimum Acceptable)

**Considerations:**
- REST API deprecated but functional
- Basic Docker Compose support
- Missing 25.10 improvements (registry mirrors, extended timeout)
- Should upgrade to 25.10 for better experience

**If Using 25.04:**
1. Upgrade to 25.10 as soon as possible
2. Already has JSON-RPC API support
3. Missing quality-of-life improvements from 25.10

### TrueNAS 25.10+ (Recommended)

**Benefits:**
- All features supported
- REST API deprecation warnings help catch issues early
- Best Docker Compose support
- Forward compatible with 26.04+
- Production-ready stability

### TrueNAS 26.04+ (Future)

**Expected Changes:**
- REST API completely removed (apps must use JSON-RPC)
- This app is already compatible (if built per these requirements)
- No migration work needed if targeting 25.10+

## Migration Path

### From TrueNAS 24.10

**Recommended Upgrade Path:**
```
24.10 → 25.04 → 25.10
```

**Steps:**
1. Backup TrueNAS configuration
2. Upgrade to 25.04 (intermediate version)
3. Verify app functionality
4. Upgrade to 25.10
5. Test MAAS app installation
6. Regenerate API keys (if using TrueNAS API integration)

**Alternative (Direct Upgrade):**
```
24.10 → 25.10
```
- Supported but riskier
- Skip intermediate version
- Test thoroughly after upgrade

### From TrueNAS 25.04

**Upgrade Path:**
```
25.04 → 25.10
```

**Steps:**
1. Backup TrueNAS configuration
2. Upgrade to 25.10
3. Test MAAS app installation
4. Verify no REST API warnings (if TrueNAS API used)

## Version Detection

### Check Your TrueNAS Version

**Via Web UI:**
1. Navigate to **System Settings > General**
2. Check "Version" field
3. Verify it shows 25.10.x or later

**Via CLI:**
```bash
# SSH to TrueNAS host
truenas-version

# Expected output:
# TrueNAS-SCALE-25.10.0
```

**Via API:**
```python
# Using JSON-RPC API
import websocket
import json

ws = websocket.create_connection("ws://truenas-host/websocket")
request = {
    "jsonrpc": "2.0",
    "method": "system.version",
    "params": [],
    "id": 1
}
ws.send(json.dumps(request))
response = json.loads(ws.recv())
print(response["result"])  # Shows version string
```

## Troubleshooting Version Issues

### Error: "Minimum version not met"

**Symptom:**
```
Error installing app: Minimum TrueNAS version 25.10.0 required, found 24.10.x
```

**Solution:**
1. Upgrade TrueNAS to 25.10 or later
2. Follow migration path above

### Warning: "REST API endpoint deprecated"

**Symptom:**
```
Daily Alert: Deprecated REST API endpoints accessed
```

**Solution:**
1. Identify which application is using REST API
2. Update to use JSON-RPC 2.0 WebSocket API
3. Regenerate API keys if needed
4. Test application functionality

### Error: "services key not found"

**Symptom:**
```
Error: Docker Compose YAML missing required 'services' key
```

**Solution:**
1. Update compose.yaml to include `services:` key
2. Format for TrueNAS 25.10+:
   ```yaml
   name: maas
   services:
     maas:
       # ... configuration
   ```

## Testing Checklist

Before deploying to production, verify:

- [ ] TrueNAS version is 25.10.0 or later
- [ ] App installs without version warnings
- [ ] No REST API deprecation alerts (if TrueNAS API used)
- [ ] Docker Compose services start successfully
- [ ] Health checks pass
- [ ] Data persists across container restarts
- [ ] App accessible via web UI
- [ ] API integration works (if applicable)

## Additional Resources

### Documentation
- [TrueNAS 25.10 Documentation](https://www.truenas.com/docs/scale/25.10/)
- [TrueNAS API Reference](https://www.truenas.com/docs/scale/25.10/api/)
- [JSON-RPC API Documentation](https://api.truenas.com/v25.04/jsonrpc.html)
- [Docker Compose Apps Guide](https://www.truenas.com/docs/scale/25.10/scaleuireference/apps/)

### Community Resources
- [TrueNAS Forums](https://forums.truenas.com/)
- [TrueNAS Apps Repository](https://github.com/truenas/apps)
- [TrueNAS Apps Market](https://apps.truenas.com/)

### Version Notes
- [25.04 Release Notes](https://www.truenas.com/docs/scale/25.04/gettingstarted/scalereleasenotes/)
- [25.10 Release Notes](https://www.truenas.com/docs/scale/25.10/gettingstarted/versionnotes/)
- [26.04 Development Notes](https://www.truenas.com/docs/scale/gettingstarted/versionnotes/)
- [Feature Deprecations](https://www.truenas.com/docs/scale/gettingstarted/deprecations/)

## Summary

**Why Target TrueNAS 25.10+?**

1. **Future-Proof**: Compatible with TrueNAS 26.04+ (REST API removal)
2. **Modern API**: Uses JSON-RPC 2.0 WebSocket (not deprecated REST)
3. **Better Docker Support**: Leverages 25.10+ Docker Compose improvements
4. **Production Ready**: Stable, tested, supported version
5. **Forward Compatible**: No migration work needed for 26.04+

**Migration Note**: If users are on older TrueNAS versions (24.10, 25.04), they should upgrade to 25.10+ before installing this app to ensure the best experience and avoid future compatibility issues.

**Do NOT Use**: TrueNAS 24.10 or earlier for new deployments. These versions lack critical features and API support required for future compatibility.
