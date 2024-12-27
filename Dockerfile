FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

# Arguments for GitHub runner version
ARG RUNNER_VERSION=2.314.1
ARG RUNNER_ARCH="x64"
ARG DOCKER_VERSION=24.0.7

# Environment variables
ENV RUNNER_TOOL_CACHE=/runner/toolcache
ENV RUNNER_ASSETS_DIR=/runner
ENV LIBVIRT_DEFAULT_URI=qemu:///system

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    tar \
    unzip \
    zip \
    jq \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    git \
    iputils-ping \
    sudo \
    # VM and virtualization packages
    qemu-system-x86 \
    qemu-kvm \
    libvirt-daemon \
    libvirt-daemon-system \
    libvirt-clients \
    # Networking tools
    net-tools \
    iproute2 \
    iptables \
    dnsutils \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce=5:${DOCKER_VERSION}* docker-ce-cli=5:${DOCKER_VERSION}* containerd.io \
    && rm -rf /var/lib/apt/lists/*

# Create runner user and add to groups
RUN useradd -m -s /bin/bash runner \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && usermod -aG kvm runner \
    && usermod -aG libvirt runner \
    && usermod -aG libvirt-qemu runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create directories and set permissions
RUN mkdir -p /runner \
    /var/run/libvirt \
    /var/lib/libvirt/qemu \
    /var/lib/libvirt/images \
    /etc/qemu \
    && chown -R root:root /var/run/libvirt \
    && chmod 755 /var/run/libvirt \
    && chown -R runner:runner /runner

# Add QEMU hook
COPY qemu-hook /etc/libvirt/hooks/qemu
RUN chmod +x /etc/libvirt/hooks/qemu

# Configure QEMU
RUN echo "user = \"runner\"" > /etc/libvirt/qemu.conf \
    && echo "group = \"runner\"" >> /etc/libvirt/qemu.conf \
    && echo "security_driver = \"none\"" >> /etc/libvirt/qemu.conf \
    && echo "cgroup_device_acl = [\n" >> /etc/libvirt/qemu.conf \
    && echo "    \"/dev/null\", \"/dev/full\", \"/dev/zero\",\n" >> /etc/libvirt/qemu.conf \
    && echo "    \"/dev/random\", \"/dev/urandom\",\n" >> /etc/libvirt/qemu.conf \
    && echo "    \"/dev/ptmx\", \"/dev/kvm\"\n" >> /etc/libvirt/qemu.conf \
    && echo "]" >> /etc/libvirt/qemu.conf

WORKDIR /runner

# Download and install GitHub runner
RUN curl -o runner.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /runner

# Create SSH directory and set permissions
RUN mkdir -p /home/runner/.ssh \
    && touch /home/runner/.ssh/known_hosts \
    && chown -R runner:runner /home/runner/.ssh \
    && chmod 700 /home/runner/.ssh

# Copy scripts
COPY --chown=runner:runner start.sh .
COPY --chown=root:root init.sh /init.sh
RUN chmod +x start.sh /init.sh

# Create work directories
RUN mkdir -p /runner/_work/_temp \
    /runner/_work/_actions \
    && chown -R runner:runner /runner/_work

ENTRYPOINT ["/init.sh"]