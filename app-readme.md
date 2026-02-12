# MAAS - Metal as a Service

## What is MAAS?

MAAS (Metal as a Service) transforms physical servers into cloud-like infrastructure that you can provision on demand. Built by Canonical, MAAS automates the entire lifecycle of bare metal servers - from discovery and provisioning to decommissioning - providing datacenter-grade infrastructure management through an intuitive web UI and powerful RESTful API.

Think of MAAS as your personal cloud for physical machines. It handles the tedious work of installing operating systems, configuring storage, managing networks, and controlling power - letting you focus on running workloads rather than managing hardware.

## Key Features

- **Automated Discovery**: Physical servers automatically enroll via PXE boot with complete hardware detection
- **Rapid Deployment**: Deploy Ubuntu, CentOS, RHEL, Windows, or custom images in under 2 minutes
- **Power Management**: Integrated control for IPMI, Redfish, BMC, and other power management interfaces
- **Storage Automation**: Automatic RAID, LVM, ZFS, and bcache configuration with erasure policies
- **Network Control**: Full DHCP, DNS, VLAN, and subnet management with traffic isolation
- **Cloud Integration**: Native support for Kubernetes, OpenStack, Terraform, Ansible, and Juju
- **RESTful API**: Complete OAuth-authenticated API for automation and programmatic control
- **High Availability**: Multi-region and rack controller support for enterprise deployments

## Use Cases

MAAS excels in environments where you need to manage physical infrastructure at scale:

- **Private Cloud**: Build your own cloud infrastructure on bare metal
- **HPC Clusters**: Deploy and manage high-performance computing environments
- **Edge Computing**: Centralized management of distributed physical infrastructure
- **CI/CD Infrastructure**: On-demand provisioning of build and test servers
- **Kubernetes**: Provision and manage bare metal Kubernetes worker nodes
- **Development Labs**: Rapidly deploy and tear down development environments

## Installation Prerequisites

Before installing MAAS on TrueNAS, ensure you meet these requirements:

### TrueNAS Requirements
- **Version**: TrueNAS 25.10.0 or later (Goldeye release)
- **Apps Feature**: Apps functionality enabled in TrueNAS

### System Resources
- **CPU**: 2 cores minimum (4 cores recommended for production)
- **Memory**: 4GB RAM minimum (8GB recommended)
- **Storage**: 120GB minimum (250GB recommended)
  - Configuration: 1GB
  - Application data: 20GB
  - Boot images: 100GB+ (depends on OS selections)
  - Database: 20GB
  - Logs: 5GB

### Network Configuration
- **Static IP**: Recommended for the MAAS server
- **Network Access**:
  - Port 5240/TCP for web UI and API
  - Port 69/UDP for TFTP/PXE boot (if using host network mode)
  - Port 8000/TCP for HTTP proxy (image downloads)
- **DHCP**: If MAAS will manage DHCP, ensure no conflicts with existing DHCP servers

### Storage Recommendations
- Use SSD storage for configuration, application data, and database
- HDD storage is acceptable for boot images (large sequential reads)
- Create dedicated TrueNAS datasets for better management

## Quick Installation Steps

### 1. Access TrueNAS Apps
- Log into your TrueNAS web interface
- Navigate to the **Apps** section
- Search for "MAAS"

### 2. Configure MAAS Application

Fill in the required configuration fields:

**MAAS Server Configuration:**
- **MAAS URL**: Full URL where MAAS will be accessible
  - Example: `http://192.168.1.100:5240/MAAS`
  - Must be reachable by machines you want to manage
  - Include the `/MAAS` path suffix

**Administrator Account:**
- **Username**: Admin username (default: admin)
- **Password**: Strong password (minimum 8 characters, 16+ recommended)
- **Email**: Your email address for notifications

**Database:**
- **PostgreSQL Password**: Secure password for database (minimum 8 characters, 16+ recommended)

**Network Mode:**
- **Host Mode** (Recommended): Required for PXE boot and full functionality
- **Bridge Mode**: For API-only or testing without PXE boot

**Storage Paths:**
- Accept defaults or customize to match your TrueNAS dataset structure
- Default: `/mnt/tank/maas/` with subdirectories

### 3. Deploy Application
- Review configuration
- Click **Install**
- Wait 2-3 minutes for deployment to complete
- Monitor deployment logs in TrueNAS Apps interface

### 4. Verify Installation
- Check that both services (MAAS and PostgreSQL) show as healthy
- Access the MAAS web UI at your configured URL
- Log in with your admin credentials

## Post-Installation Configuration

After installation, complete these essential steps:

### 1. Import Boot Images

MAAS requires OS boot images before it can deploy machines:

1. Log into MAAS web UI
2. Navigate to **Settings > Images**
3. Select operating systems to import:
   - Ubuntu 22.04 LTS (Recommended)
   - Ubuntu 24.04 LTS (Recommended)
   - CentOS, RHEL, Windows (as needed)
4. Click **Import** and wait for download (10-30 minutes)
5. Monitor import progress in Images section

**Note**: Each image requires 2-5GB of storage. Plan accordingly.

### 2. Configure DNS Services

If MAAS will provide DNS for your infrastructure:

1. Go to **Settings > Network Services > DNS**
2. Set upstream DNS servers (e.g., 8.8.8.8, 8.8.4.4)
3. Configure DNS forwarder settings
4. Enable DNS management

### 3. Set Up DHCP (For PXE Boot)

Required for automatic machine discovery:

1. Navigate to **Subnets**
2. Select your network subnet
3. Click **Configure DHCP**
4. Define IP ranges:
   - **Dynamic Range**: IPs for MAAS-managed machines
   - **Reserved Ranges**: Exclude existing infrastructure
5. Enable DHCP on the subnet
6. Save configuration

**Important**: Ensure no conflicts with existing DHCP servers on the network.

### 4. Add SSH Keys

For secure access to deployed machines:

1. Click your username (top right)
2. Go to **SSH Keys**
3. Click **Add SSH Key**
4. Paste your public SSH key
5. MAAS will automatically inject this into all deployed machines

### 5. Enroll Your First Machine

**Method A: PXE Boot (Automatic)**
1. Configure machine BIOS for network boot (PXE/iPXE)
2. Connect machine to same network as MAAS
3. Power on machine
4. Machine appears in MAAS as "New"
5. Commission and deploy

**Method B: IPMI/BMC (Manual)**
1. Navigate to **Machines > Add Hardware**
2. Select "Machine"
3. Enter details:
   - Hostname
   - Power type (IPMI, Redfish, etc.)
   - BMC IP address and credentials
4. Save machine
5. Commission and deploy

## Important Notes and Warnings

### Network Mode Selection

**Host Network Mode (Recommended):**
- Required for PXE boot functionality
- Required for DHCP server functionality
- MAAS uses ports directly on TrueNAS host
- Best performance and full feature set
- Check for port conflicts before installation

**Bridge Network Mode:**
- Use only for API-only deployments
- PXE boot will NOT work
- DHCP server will NOT work
- Good for testing or integration scenarios
- Network isolation provided

### Storage Considerations

**Boot Images:**
- Each OS image requires 2-5GB storage
- Ubuntu 22.04 LTS + 24.04 LTS = approximately 10GB
- Plan for 100GB+ if deploying multiple OS versions
- Images can be deleted when no longer needed

**Database:**
- PostgreSQL data grows with managed machines
- Plan 1-2GB per 100 managed machines
- Regular backups recommended

**Logs:**
- Logs rotate automatically
- 5GB allocation recommended
- Monitor disk usage periodically

### Security Considerations

**Passwords:**
- Use strong, unique passwords (16+ characters recommended)
- Store passwords securely (password manager)
- Never commit passwords to version control

**Network Access:**
- Restrict MAAS UI access to authorized networks
- Use firewall rules to limit exposure
- Consider VPN for remote access
- Enable HTTPS via reverse proxy for production

**Power Management:**
- IPMI/BMC credentials provide full power control
- Secure BMC interfaces on separate management network
- Use strong BMC passwords
- Regularly audit BMC access logs

### Performance Tips

**Storage Optimization:**
- Use SSD storage for database (PostgreSQL)
- Use SSD storage for config and data directories
- HDD acceptable for boot images (large sequential reads)

**Network Optimization:**
- Use gigabit or faster network for image deployment
- Separate management and deployment networks if possible
- Monitor network bandwidth during image imports

**Resource Allocation:**
- Increase CPU allocation for faster image imports
- Increase memory for managing 100+ machines
- Monitor resource usage in TrueNAS Apps

### Backup Recommendations

**Critical Data:**
- PostgreSQL database (machine inventory and configuration)
- Configuration directory (MAAS settings)
- Data directory (commissioning data)

**Backup Strategy:**
- Schedule daily database backups
- Store backups on separate storage
- Test restore procedures regularly
- Keep multiple backup generations

**Backup Command:**
```bash
# Access TrueNAS shell and run:
docker compose exec -T maas-postgres pg_dump -U maas maasdb > /mnt/backups/maas_$(date +%Y%m%d).sql
```

### Common Issues and Solutions

**MAAS won't start:**
- Verify storage directories exist and have correct permissions
- Check that passwords are set in configuration
- Review logs in TrueNAS Apps interface
- Ensure no port conflicts (especially port 5240)

**PXE boot not working:**
- Verify host network mode is enabled
- Check that port 69/UDP is accessible
- Ensure no firewall blocking TFTP
- Verify machines are on same network as MAAS

**Can't access web UI:**
- Verify MAAS service is running and healthy
- Check MAAS URL is correct
- Test from TrueNAS: `curl http://localhost:5240/MAAS/`
- Check firewall rules

**Database connection errors:**
- Verify PostgreSQL service is healthy
- Check database password matches configuration
- Review PostgreSQL logs
- Restart services if needed

## Getting Started After Installation

### Your First Deployment

1. **Import Images** (30 minutes)
   - Select Ubuntu 22.04 LTS
   - Wait for import to complete

2. **Configure Network** (10 minutes)
   - Set up DHCP on your subnet
   - Configure DNS forwarder

3. **Add SSH Key** (2 minutes)
   - Add your public SSH key
   - Enables secure access to deployed machines

4. **Enroll Machine** (5 minutes)
   - Use PXE boot or manual IPMI
   - Wait for machine to appear in MAAS

5. **Commission Machine** (10 minutes)
   - Select machine
   - Click Commission
   - MAAS inventories hardware

6. **Deploy Machine** (2 minutes)
   - Select machine
   - Choose OS (Ubuntu 22.04 LTS)
   - Click Deploy
   - Machine ready in 2-5 minutes

7. **Access Machine** (instant)
   - SSH to deployed machine
   - Your SSH key already injected
   - Start using your infrastructure

## Support and Resources

### Documentation
- **MAAS Official Docs**: https://maas.io/docs
- **MAAS API Reference**: https://maas.io/docs/api
- **TrueNAS Apps Guide**: https://www.truenas.com/docs/truenasapps/
- **GitHub Repository**: https://github.com/cpfarhood/truenas-maas-app

### Community Support
- **MAAS Discourse**: https://discourse.maas.io
- **TrueNAS Forums**: https://forums.truenas.com/
- **GitHub Issues**: https://github.com/cpfarhood/truenas-maas-app/issues

### Commercial Support
- **Canonical (MAAS)**: https://ubuntu.com/support
- **iXsystems (TrueNAS)**: https://www.ixsystems.com/support/

## What's Next?

After deploying your first machine:

- **Explore API**: Automate deployments with MAAS RESTful API
- **Try Kubernetes**: Deploy Kubernetes cluster on bare metal
- **Integrate Tools**: Connect MAAS with Terraform, Ansible, or Juju
- **Scale Up**: Add more machines and expand your infrastructure
- **High Availability**: Add rack controllers for redundancy

MAAS transforms how you manage physical infrastructure. What took hours now takes minutes. Welcome to the world of Metal as a Service.

---

**Version**: 1.0.0 | **MAAS Version**: 3.5 | **TrueNAS**: 25.10+

For detailed technical documentation, see the [full README](README.md).
