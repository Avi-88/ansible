# Use the latest official Python image as base
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sshpass \
        git \
        curl \
        build-essential \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Ansible, Nutanix SDK, and the Nutanix Collection
RUN pip install --upgrade pip \
    && pip install ansible \
    && ansible-galaxy collection install nutanix.ncp

# Set working directory
WORKDIR /workspace

# Optionally copy your playbooks and vars here
# COPY . /workspace

# Default command
CMD ["sleep", "infinity"]