# Nutanix Cluster Deployment Automation - Design Document

## Executive Summary

This document outlines the design and implementation of an Ansible-based automation solution for Nutanix cluster deployment. The solution provides two deployment methods (Foundation Central and Foundation VM) with comprehensive error handling, validation, and monitoring capabilities.

---

## 1. Problem Statement

### Business Challenges

- **Manual Deployment Complexity**: Traditional Nutanix cluster deployment requires multiple manual steps, increasing deployment time and error potential
- **Inconsistency**: Manual processes lead to configuration drift and inconsistent deployments
- **Scalability**: Manual deployment doesn't scale for multiple clusters or frequent deployments
- **Error-Prone**: Human error in IP configuration, serial number entry, and network settings

### Technical Challenges

- **Long-Running Operations**: Cluster deployment can take 1-2 hours, requiring robust monitoring
- **Network Dependencies**: Multiple network segments (CVM, Hypervisor, IPMI) must be validated
- **API Integration**: Integration with Foundation Central and Foundation VM APIs
- **Error Recovery**: Handling network interruptions and partial failures

---

## 2. Solution Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Ansible Control Node                         │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Playbook Orchestration Layer                 │ │
│  │  ┌──────────────┐              ┌──────────────┐         │ │
│  │  │ FC Playbooks │              │ FVM Playbooks │         │ │
│  │  └──────┬───────┘              └──────┬───────┘         │ │
│  └─────────┼──────────────────────────────┼─────────────────┘ │
│            │                              │                    │
│  ┌─────────▼──────────────────────────────▼─────────────────┐ │
│  │         Nutanix NCP Collection (Ansible Modules)        │ │
│  └─────────────────────────────────────────────────────────┘ │
└───────────────────────────┬───────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
    ┌───────▼────────┐            ┌────────▼────────┐
    │ Foundation     │            │ Foundation VM    │
    │ Central API    │            │ (On-Premises)    │
    │ (Cloud)        │            │                  │
    └───────┬────────┘            └────────┬─────────┘
            │                              │
            └──────────────┬───────────────┘
                           │
                  ┌────────▼────────┐
                  │  Nutanix Nodes  │
                  │  (Hardware)     │
                  └─────────────────┘
```

### 2.2 Component Breakdown

#### Ansible Control Node
- Executes playbooks
- Manages inventory and variables
- Handles credential management (via Ansible Vault)

#### Foundation Central (FC)
- Cloud-based service
- Node discovery and management
- Cluster deployment orchestration
- RESTful API interface

#### Foundation VM (FVM)
- On-premises deployment option
- Foundation services running on VM
- Direct API access
- Network validation capabilities

#### Nutanix NCP Collection
- Ansible modules for Nutanix operations
- Abstracts API complexity
- Provides idempotent operations

---

## 3. Design Decisions

### 3.1 Why Ansible?

**Rationale:**
- **Declarative Language**: YAML-based playbooks are readable and maintainable
- **Idempotency**: Built-in support for idempotent operations
- **Extensibility**: Large ecosystem of modules and collections
- **Agentless**: No agents required on target systems
- **Mature Ecosystem**: Well-established in enterprise environments

**Alternatives Considered:**
- **Terraform**: Better for infrastructure provisioning, but less suitable for configuration management
- **Python Scripts**: More flexible but requires more code and error handling
- **Puppet/Chef**: Require agents, more complex setup

### 3.2 Two Deployment Methods

**Decision**: Support both FC and FVM deployment methods

**Rationale:**
- **FC Method**: 
  - Suitable for cloud-managed environments
  - No on-premises Foundation VM required
  - Centralized management
  
- **FVM Method**:
  - Required for air-gapped environments
  - Full control over deployment
  - Direct API access

**Trade-offs:**
- More code to maintain
- Different API interfaces
- Different validation requirements

### 3.3 Modular Playbook Design

**Decision**: Separate playbooks for different phases

**Structure:**
```
FVM Deployment:
├── prechecks.yml          # Validation phase
├── deploy_cluster.yml     # Deployment phase
├── progress.yml           # Monitoring (included)
├── configure_cluster.yml  # Configuration phase
└── register_to_PC.yml     # Registration phase
```

**Benefits:**
- **Reusability**: Can run phases independently
- **Debugging**: Easier to identify issues in specific phases
- **Flexibility**: Skip or repeat phases as needed
- **Maintainability**: Smaller, focused playbooks

**Trade-offs:**
- More files to manage
- Need to ensure proper execution order

### 3.4 Asynchronous Job Handling

**Decision**: Use async/polling for long-running deployment tasks

**Implementation:**
```yaml
- name: Start cluster creation (asynchronous)
  nutanix.ncp.ntnx_foundation_central:
    # ... parameters ...
  async: 7200  # 2 hours
  poll: 0      # Don't wait
  register: foundation_job

- name: Wait for completion
  ansible.builtin.async_status:
    jid: "{{ foundation_job.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 240
  delay: 30
```

**Benefits:**
- Prevents playbook timeouts
- Allows progress monitoring
- Handles network interruptions

**Alternative Considered:**
- Synchronous execution with increased timeout
- **Rejected**: Risk of playbook timeouts, no progress visibility

### 3.5 Network Validation Strategy

**Decision**: Pre-deployment network validation for FVM method

**Implementation:**
- Port connectivity checks (IPMI ports: 80, 443, 623)
- Traceroute validation for cluster network
- Validates paths before deployment starts

**Benefits:**
- Fail fast if network issues exist
- Clear error messages for network problems
- Reduces deployment failures

**Trade-offs:**
- Adds time to deployment process
- May not catch all network issues

### 3.6 Variable Management

**Decision**: Separate variables from playbooks

**Structure:**
```
group_vars/all/
├── cluster_vars.yml      # Configuration
└── nutanix_secrets.yml   # Credentials (vault-encrypted)
```

**Benefits:**
- **Security**: Secrets can be vault-encrypted
- **Reusability**: Same playbooks, different configs
- **Maintainability**: Easy to update configurations

**Best Practices:**
- Use Ansible Vault for secrets
- Document all required variables
- Provide example configurations

---

## 4. Implementation Details

### 4.1 FC Deployment Flow

```
1. Node Discovery
   ├── Query Foundation Central for available nodes
   ├── Filter by node state (STATE_AVAILABLE)
   └── Create serial number → UUID mapping

2. Node Validation
   ├── Match configured serial numbers with discovered nodes
   └── Fail if any configured node not found

3. Cluster Deployment
   ├── Construct deployment payload
   ├── Submit to Foundation Central (async)
   └── Monitor job progress

4. Progress Monitoring
   ├── Poll job status every 30 seconds
   ├── Display progress percentage
   └── Handle completion or failure
```

### 4.2 FVM Deployment Flow

```
1. Pre-Validation
   ├── Check IPMI connectivity (ports 80, 443, 623)
   ├── Validate network paths (traceroute)
   └── Verify Foundation VM accessibility

2. Deployment Preparation
   ├── Validate required variables
   ├── Construct Foundation API payload
   └── Display deployment summary

3. Cluster Deployment
   ├── POST to Foundation API /image_nodes
   ├── Extract session ID
   └── Start progress monitoring

4. Progress Monitoring (Recursive)
   ├── GET /progress?session_id=<id>
   ├── Display progress
   ├── Check for completion/failure
   └── Recursively call progress.yml until done

5. Post-Deployment Configuration
   ├── Configure NTP servers
   ├── Configure Data Services IP (DSIP)
   └── Optional: Register to Prism Central
```

### 4.3 Error Handling Strategy

#### Validation Errors
- **Input Validation**: Check required variables before execution
- **Network Validation**: Pre-deployment connectivity checks
- **Node Validation**: Ensure all nodes are discoverable

#### Runtime Errors
- **API Errors**: Clear error messages with context
- **Network Interruptions**: Graceful handling in async jobs
- **Timeout Handling**: Configurable retries and timeouts

#### Recovery Strategy
- **Idempotent Operations**: Safe to re-run playbooks
- **State Checking**: Verify current state before changes
- **Partial Failure Handling**: Clear indication of what succeeded/failed

### 4.4 Progress Monitoring Implementation

**Challenge**: Long-running deployments (1-2 hours) require progress visibility

**Solution**: Recursive task inclusion with state tracking

```yaml
# progress.yml
- name: Get foundation progress
  ansible.builtin.uri:
    url: "{{ foundation_api_base }}/progress?session_id={{ foundation_session_id }}"
  register: progress_result

- name: Display progress
  ansible.builtin.debug:
    msg: "Progress: {{ progress_result.json.aggregate_percent_complete }}%"

- name: Check for completion
  ansible.builtin.set_fact:
    foundation_complete: true
  when: progress_result.json.aggregate_percent_complete == 100

- name: Continue monitoring recursively
  include_tasks: progress.yml
  when: not (foundation_complete | default(false))
```

**Benefits:**
- Real-time progress updates
- Automatic termination on completion
- Handles failures gracefully

---

## 5. Security Considerations

### 5.1 Credential Management

**Implementation:**
- Use Ansible Vault for sensitive data
- Separate secrets from configuration
- Never commit unencrypted credentials

**Example:**
```bash
ansible-vault encrypt group_vars/all/nutanix_secrets.yml
```

### 5.2 Network Security

- Use SSH keys where possible
- Disable certificate validation only in controlled environments
- Document security implications

### 5.3 Access Control

- Limit playbook execution to authorized users
- Use least-privilege principles for API credentials
- Audit playbook executions

---

## 6. Testing Strategy

### 6.1 Unit Testing

- Test individual tasks in isolation
- Validate variable transformations
- Test error conditions

### 6.2 Integration Testing

- Test full deployment flow in test environment
- Validate API interactions
- Test error recovery

### 6.3 Validation Testing

- Network connectivity scenarios
- Node discovery edge cases
- Progress monitoring edge cases

---

## 7. Lessons Learned

### 7.1 What Worked Well

1. **Modular Design**: Separating phases made debugging easier
2. **Pre-Validation**: Catching network issues early saved time
3. **Progress Monitoring**: Real-time feedback improved user experience
4. **Error Messages**: Clear error messages reduced troubleshooting time

### 7.2 Challenges Overcome

1. **Long-Running Tasks**: Async/polling pattern solved timeout issues
2. **Network Validation**: Comprehensive prechecks reduced deployment failures
3. **API Complexity**: Nutanix NCP collection simplified API interactions
4. **State Management**: Recursive progress monitoring handled state correctly

### 7.3 Future Improvements

1. **Parallel Deployments**: Support deploying multiple clusters simultaneously
2. **Rollback Capability**: Add ability to rollback failed deployments
3. **Enhanced Monitoring**: Integration with monitoring systems
4. **Template Library**: Pre-built templates for common scenarios

---

## 8. Performance Considerations

### 8.1 Execution Time

- **Prechecks**: ~2-5 minutes
- **Deployment**: 1-2 hours (hardware-dependent)
- **Configuration**: ~5-10 minutes
- **Total**: ~1.5-2.5 hours

### 8.2 Resource Usage

- **Ansible Control Node**: Minimal CPU/memory
- **Network**: Moderate bandwidth during deployment
- **Foundation VM/FC**: API request overhead

### 8.3 Optimization Opportunities

- Parallel node validation
- Batch API requests where possible
- Caching discovery results

---

## 9. Maintenance & Support

### 9.1 Documentation

- Comprehensive README
- Inline code comments
- Variable documentation
- Troubleshooting guide

### 9.2 Version Control

- Git-based version control
- Tag releases
- Maintain changelog

### 9.3 Updates

- Monitor Nutanix NCP collection updates
- Test with new AOS versions
- Update playbooks for API changes

---

## 10. Conclusion

This automation solution successfully addresses the challenges of manual Nutanix cluster deployment by providing:

- **Automation**: Reduces manual effort and errors
- **Consistency**: Ensures repeatable deployments
- **Reliability**: Comprehensive error handling and validation
- **Flexibility**: Supports multiple deployment methods
- **Maintainability**: Well-structured, documented code

The modular design and comprehensive error handling make this solution suitable for enterprise production environments.

---

**Document Version**: 1.0  
**Last Updated**: 2025  
**Author**: Infrastructure Automation Team

