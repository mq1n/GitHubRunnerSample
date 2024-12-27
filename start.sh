#!/bin/bash

RUNNER_ASSETS_DIR=${RUNNER_ASSETS_DIR:-/runner}

# # Print all environment variables for debugging
# echo "=== Environment Variables Before sudo ==="
# env | sort
# echo

# Import environment variables from a file
env | grep -E '^(RUNNER_|GITHUB_|LIBVIRT_)' > /tmp/runner_env

# Wait for libvirt to be ready
while [ ! -e /var/run/libvirt/libvirt-sock ]; do
    echo "Waiting for libvirt socket..."
    sleep 1
done

# Set up VM networking
sudo bash -c 'echo "127.0.0.1 localhost" > /etc/hosts'
sudo bash -c 'echo "127.0.0.1 freebsd" >> /etc/hosts'

# Set up SSH config for FreeBSD VM
mkdir -p ~/.ssh
cat > ~/.ssh/config << EOF
Host freebsd
    HostName localhost
    Port 2222
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chmod 600 ~/.ssh/config

cd ${RUNNER_ASSETS_DIR}

# Source the environment variables
set -a
source /tmp/runner_env
set +a

echo "=== GitHub Runner Configuration ==="
echo "Repository URL: ${RUNNER_REPOSITORY_URL}"
echo "Runner Token: ${GITHUB_ACCESS_TOKEN:0:4}... (truncated)"
echo "Runner Name: ${RUNNER_NAME}"
echo "Runner Labels: ${RUNNER_LABELS}"
echo "Work Directory: ${RUNNER_WORK_DIRECTORY}"
echo "=============================="

# Check required variables
if [ -z "${RUNNER_REPOSITORY_URL}" ]; then
    echo "Error: RUNNER_REPOSITORY_URL is not set"
    exit 1
fi

if [ -z "${GITHUB_ACCESS_TOKEN}" ]; then
    echo "Error: GITHUB_ACCESS_TOKEN is not set"
    exit 1
fi

# If the runner was registered before in a previous run, remove it
if [ -f .runner ]; then
    ./config.sh remove --token ${GITHUB_ACCESS_TOKEN}
fi

# Configure the runner
./config.sh \
    --unattended \
    --url ${RUNNER_REPOSITORY_URL} \
    --token ${GITHUB_ACCESS_TOKEN} \
    --name ${RUNNER_NAME:-$(hostname)} \
    --labels ${RUNNER_LABELS:-default} \
    --work ${RUNNER_WORK_DIRECTORY:-_work} \
    --replace

# Start the runner
exec ./run.sh