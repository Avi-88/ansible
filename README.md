# Nutanix Cluster Deployment Automation with Ansible

## Overview

This repository contains Ansible playbooks for automating Nutanix cluster deployment. The automation supports two deployment methods:

1. **Foundation Central (FC)** - Cloud-based deployment service
2. **Foundation VM (FVM)** - On-premises Foundation VM deployment

These playbooks demonstrate enterprise-grade automation practices for infrastructure deployment, including validation, error handling, and progress monitoring.

---

## Table of Contents

- [Architecture](#architecture)
- [Design Process](#design-process)
- [Deployment Methods](#deployment-methods)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Playbook Structure](#playbook-structure)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Ansible Control Node                      │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │  FC Deployment   │         │  FVM Deployment  │          │
│  │   Playbooks      │         │   Playbooks      │          │
│  └────────┬─────────┘         └────────┬─────────┘          │
└───────────┼─────────────────────────────┼────────────────────┘
            │                             │
            │                             │
    ┌───────▼────────┐           ┌────────▼────────┐
    │ Foundation     │           │ Foundation VM   │
    │ Central API    │           │ (On-Premises)   │
    └───────┬────────┘           └────────┬────────┘
            │                             │
            │                             │
    ┌───────▼─────────────────────────────▼────────┐
    │         Nutanix Hardware Nodes                │
    │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
    │  │  Node A  │  │  Node B  │  │  Node C  │   │
    │  └──────────┘  └──────────┘  └──────────┘   │
    └──────────────────────────────────────────────┘
```

### Component Overview

1. **Ansible Control Node**: Executes playbooks and orchestrates deployment
2. **Foundation Central**: Nutanix cloud service for cluster deployment
3. **Foundation VM**: On-premises virtual machine running Foundation services
4. **Nutanix Nodes**: Physical hardware nodes that form the cluster

---

## Design Process

### 1. Requirements Analysis

**Business Requirements:**
- Automate repetitive cluster deployment tasks
- Reduce manual errors in configuration
- Enable consistent, repeatable deployments
- Support multiple deployment scenarios (FC and FVM)

**Technical Requirements:**
- Idempotent operations
- Error handling and validation
- Progress monitoring for long-running tasks
- Secure credential management
- Network connectivity validation

### 2. Architecture Design

**Key Design Decisions:**

- **Separation of Concerns**: Separate playbooks for FC and FVM deployments
- **Modularity**: Break down deployment into logical phases (prechecks, deployment, configuration)
- **Reusability**: Use variables and templates for configuration
- **Error Handling**: Implement validation checks before deployment
- **Asynchronous Operations**: Handle long-running deployment tasks with async/polling

### 3. Implementation Phases

#### Phase 1: Foundation Setup
- Node discovery and validation
- Network connectivity checks
- Credential verification

#### Phase 2: Deployment
- Cluster creation initiation
- Progress monitoring
- Error detection and handling

#### Phase 3: Post-Deployment
- Cluster configuration (NTP, DSIP, etc.)
- Prism Central registration
- Validation and verification

### 4. Testing & Validation

- Unit testing of individual tasks
- Integration testing with test environments
- Error scenario testing
- Network failure simulation

---

## Deployment Methods

### Method 1: Foundation Central (FC) Deployment

**Use Case**: Cloud-managed deployment through Prism Central

**Advantages:**
- No on-premises Foundation VM required
- Centralized management
- API-driven automation

**Playbook Location**: `FC_nutanix_cluster_deployment/playbooks/deploy_cluster.yml`

**Key Features:**
- Automatic node discovery from Foundation Central
- Serial number to UUID mapping
- Asynchronous job monitoring
- Error handling for network interruptions

### Method 2: Foundation VM (FVM) Deployment

**Use Case**: On-premises deployment using Foundation VM

**Advantages:**
- Full control over deployment environment
- Works in air-gapped environments
- Direct API access

**Playbook Location**: `FVM_nutanix_cluster_deployment/playbooks/`

**Key Features:**
- Network pre-validation (traceroute, port checks)
- Foundation API integration
- Recursive progress monitoring
- Post-deployment configuration automation

---

## Prerequisites

### Software Requirements

- **Ansible**: Version 2.9 or higher
- **Python**: 3.6 or higher
- **Nutanix NCP Collection**: `nutanix.ncp` (installed via ansible-galaxy)

### Infrastructure Requirements

#### For FC Deployment:
- Prism Central access with Foundation Central enabled
- Network connectivity to Prism Central
- Nodes discovered in Foundation Central

#### For FVM Deployment:
- Foundation VM deployed and accessible
- Network connectivity from Ansible control node to Foundation VM
- Network connectivity from Foundation VM to target nodes

### Credentials Required

- Foundation Central/Prism Central credentials
- IPMI credentials for nodes
- Foundation VM SSH credentials (for FVM method)
- Cluster admin credentials

---

## Quick Start

### 1. Install Dependencies

```bash
# Create virtual environment (recommended)
python3 -m venv ansible-env
source ansible-env/bin/activate

# Install Ansible
pip install ansible

# Install Nutanix NCP collection
ansible-galaxy collection install nutanix.ncp
```

### 2. Configure Variables

#### For FC Deployment:

Edit `FC_nutanix_cluster_deployment/group_vars/all/nutanix_secrets.yml`:
```yaml
fc_ip_address: "your-prism-central-ip"
fc_username: "your-username"
fc_password: "your-password"
default_ipmi_password: "your-ipmi-password"
```

Edit `FC_nutanix_cluster_deployment/group_vars/all/cluster_vars.yml`:
- Update cluster details
- Configure node serial numbers and IP addresses
- Set AOS package and hypervisor ISO details

#### For FVM Deployment:

Edit `FVM_nutanix_cluster_deployment/playbooks/cluster_vars.yml`:
- Configure foundation VM IP
- Set cluster configuration
- Define node details
- Configure network settings

Edit `FVM_nutanix_cluster_deployment/inventory.ini`:
- Set Foundation VM connection details
- Configure CVM connection (for post-deployment)

### 3. Run Deployment

#### FC Deployment:
```bash
cd FC_nutanix_cluster_deployment/playbooks
ansible-playbook deploy_cluster.yml
```

#### FVM Deployment:
```bash
cd FVM_nutanix_cluster_deployment/playbooks

# Step 1: Run prechecks
ansible-playbook prechecks.yml -i ../inventory.ini

# Step 2: Deploy cluster
ansible-playbook deploy_cluster.yml -i ../inventory.ini

# Step 3: Configure cluster (after deployment completes)
ansible-playbook configure_cluster.yml -i ../inventory.ini

# Step 4: Register to Prism Central (optional)
ansible-playbook register_to_PC.yml -i ../inventory.ini
```

---

## Playbook Structure

### FC Deployment Structure

```
FC_nutanix_cluster_deployment/
├── group_vars/
│   └── all/
│       ├── cluster_vars.yml      # Cluster and node configuration
│       └── nutanix_secrets.yml   # Credentials (use ansible-vault)
└── playbooks/
    └── deploy_cluster.yml        # Main deployment playbook
```

**Play 1: Node Discovery**
- Queries Foundation Central for available nodes
- Maps configured serial numbers to discovered UUIDs
- Validates all nodes are found

**Play 2: Cluster Deployment**
- Initiates cluster creation (asynchronous)
- Monitors job progress
- Handles network interruptions gracefully

### FVM Deployment Structure

```
FVM_nutanix_cluster_deployment/
├── group_vars/
│   └── all/                      # Empty (vars in playbooks/)
├── playbooks/
│   ├── cluster_vars.yml          # All configuration variables
│   ├── prechecks.yml             # Network validation
│   ├── deploy_cluster.yml        # Main deployment
│   ├── progress.yml              # Progress monitoring (included)
│   ├── configure_cluster.yml     # Post-deployment config
│   ├── configuration_phase_1.yml # Pre-configuration tasks
│   └── register_to_PC.yml       # Prism Central registration
└── inventory.ini                  # Host inventory
```

**Key Playbooks:**

1. **prechecks.yml**: Validates network connectivity before deployment
2. **deploy_cluster.yml**: Orchestrates cluster deployment
3. **progress.yml**: Recursive task for monitoring deployment progress
4. **configure_cluster.yml**: Configures NTP, DSIP, and other cluster settings
5. **register_to_PC.yml**: Registers cluster to Prism Central

---

## Best Practices

### 1. Security

- **Use Ansible Vault** for sensitive data:
  ```bash
  ansible-vault encrypt group_vars/all/nutanix_secrets.yml
  ```

- **Never commit credentials** to version control
- Use environment variables or external secret management systems

### 2. Variable Management

- Separate configuration from code
- Use descriptive variable names
- Document required variables
- Provide default values where appropriate

### 3. Error Handling

- Validate inputs before execution
- Implement retry logic for transient failures
- Provide clear error messages
- Log important events

### 4. Idempotency

- Design tasks to be idempotent
- Check state before making changes
- Use appropriate Ansible modules

### 5. Testing

- Test in non-production environments first
- Validate network connectivity before deployment
- Test error scenarios
- Document known issues and workarounds

### 6. Documentation

- Comment complex logic
- Document variable requirements
- Maintain runbooks for common operations
- Update documentation with code changes

---

## Troubleshooting

### Common Issues

#### 1. Nodes Not Discovered (FC Deployment)

**Symptom**: Playbook fails with "No available nodes found"

**Solutions:**
- Verify nodes are powered on
- Check DHCP configuration
- Ensure nodes are in Foundation Central
- Verify network connectivity

#### 2. Network Connectivity Issues (FVM Deployment)

**Symptom**: Prechecks fail or deployment times out

**Solutions:**
- Run `prechecks.yml` to identify specific connectivity issues
- Verify firewall rules
- Check routing configuration
- Ensure Foundation VM can reach nodes

#### 3. Deployment Timeout

**Symptom**: Deployment exceeds expected time

**Solutions:**
- Check Foundation VM/FC logs
- Verify node hardware status
- Review network performance
- Increase timeout values if needed

#### 4. Authentication Failures

**Symptom**: API calls fail with authentication errors

**Solutions:**
- Verify credentials in secrets file
- Check account permissions
- Ensure certificates are valid (or disable validation)
- Test credentials manually

### Debugging Tips

1. **Enable Verbose Output**:
   ```bash
   ansible-playbook deploy_cluster.yml -vvv
   ```

2. **Test Individual Tasks**:
   Use `--tags` to run specific tasks:
   ```bash
   ansible-playbook deploy_cluster.yml --tags "discovery"
   ```

3. **Check Ansible Facts**:
   Add debug tasks to inspect variables:
   ```yaml
   - name: Debug variable
     ansible.builtin.debug:
       var: discovered_nodes_result
   ```

4. **Review Logs**:
   - Foundation VM logs: `/var/log/foundation/`
   - Prism Central logs: Available in Prism Central UI

---

## Session Presentation Guide

### Key Points to Cover

1. **Problem Statement**
   - Manual cluster deployment is time-consuming and error-prone
   - Need for automation in enterprise environments

2. **Solution Architecture**
   - Two deployment methods (FC vs FVM)
   - Modular playbook design
   - Separation of concerns

3. **Design Decisions**
   - Why Ansible?
   - Why separate playbooks?
   - Error handling strategy
   - Progress monitoring approach

4. **Implementation Highlights**
   - Node discovery automation
   - Asynchronous job handling
   - Network validation
   - Post-deployment automation

5. **Lessons Learned**
   - Importance of pre-validation
   - Handling long-running tasks
   - Error recovery strategies
   - Security considerations

### Demo Flow

1. Show playbook structure
2. Walk through variable configuration
3. Run prechecks (FVM method)
4. Demonstrate deployment execution
5. Show progress monitoring
6. Display post-deployment configuration

---

## Additional Resources

- [Nutanix Foundation Central Documentation](https://portal.nutanix.com/page/documents/details?targetId=Foundation-Central-Guide-v4_5:Foundation-Central-Guide-v4_5)
- [Nutanix NCP Ansible Collection](https://galaxy.ansible.com/nutanix/ncp)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

---

## License

This repository is provided as-is for educational and demonstration purposes.

---

## Contact & Support

For questions or issues related to this automation:
- Review the troubleshooting section
- Check Nutanix documentation
- Consult Ansible documentation for module-specific issues

---

**Last Updated**: 2025

