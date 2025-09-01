FROM python:3.6-slim

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

#install sdks for api calls

RUN pip install --no-cache-dir ntnx_clustermgmt_py_client ntnx_prism_py_client


# Install Nutanix NCP collection
RUN ansible-galaxy collection install nutanix.ncp


# Set workdir
WORKDIR /workspace

# Clone the playbook repository
RUN git clone https://github.com/Avi-88/ansible

# Default command
CMD ["/bin/bash"]