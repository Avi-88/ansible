FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sshpass \
        git \
        openssh-client \
        gcc \
        libffi-dev \
        libssl-dev \
        python3-dev \
        && rm -rf /var/lib/apt/lists/*

# Install Ansible
RUN pip install --no-cache-dir ansible

# Install Nutanix NCP collection
RUN ansible-galaxy collection install nutanix.ncp

# Set workdir
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]