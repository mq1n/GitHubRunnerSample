#!/bin/bash

# Create required directories
mkdir -p /var/log/qemu
chown runner:runner /var/log/qemu
chmod 755 /var/log/qemu

# Create cgroup directories
mkdir -p /sys/fs/cgroup/machine/
mkdir -p /sys/fs/cgroup/system/
mkdir -p /sys/fs/cgroup/system.slice/
chmod -R 777 /sys/fs/cgroup/machine/
chmod -R 777 /sys/fs/cgroup/system/
chmod -R 777 /sys/fs/cgroup/system.slice/

# Setup KVM
if [ -e /dev/kvm ]; then
    chown root:kvm /dev/kvm
    chmod 666 /dev/kvm
fi

# Configure libvirtd
cat > /etc/libvirt/libvirtd.conf << EOF
listen_tls = 0
listen_tcp = 1
unix_sock_group = "libvirt"
unix_sock_ro_perms = "0777"
unix_sock_rw_perms = "0770"
auth_unix_ro = "none"
auth_unix_rw = "none"
log_level = 1
log_filters="1:qemu 1:libvirt 3:security 3:event 3:json 3:file 3:object"
log_outputs="1:file:/var/log/libvirt/libvirtd.log"
EOF

# Configure QEMU
cat > /etc/libvirt/qemu.conf << EOF
stdio_handler = "file"
user = "runner"
group = "runner"
security_driver = "none"
log_directory = "/var/log/qemu"
EOF

# Start libvirt daemon
mkdir -p /var/log/libvirt
chown -R runner:runner /var/log/libvirt
/usr/sbin/libvirtd -d
/usr/sbin/virtlogd -d

# Wait for libvirt socket
timeout=30
while [ ! -e /var/run/libvirt/libvirt-sock ] && [ $timeout -gt 0 ]; do
    echo "Waiting for libvirt socket... ($timeout seconds left)"
    sleep 1
    timeout=$((timeout - 1))
done

# Configure default network and wait for it to be ready
virsh net-define /etc/libvirt/qemu/networks/default.xml || true
virsh net-start default || true
virsh net-autostart default || true

# Wait for network to be ready
timeout=30
while ! virsh net-list | grep -q "default.*active" && [ $timeout -gt 0 ]; do
    echo "Waiting for default network... ($timeout seconds left)"
    sleep 1
    timeout=$((timeout - 1))
done

# Configure SSH for FreeBSD VM
sudo -u runner bash -c 'mkdir -p /home/runner/.ssh'
sudo -u runner bash -c 'chmod 700 /home/runner/.ssh'
sudo -u runner bash -c 'touch /home/runner/.ssh/config'
sudo -u runner bash -c 'echo -e "Host freebsd\n  HostName 127.0.0.1\n  Port 2222\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null" > /home/runner/.ssh/config'
sudo -u runner bash -c 'chmod 600 /home/runner/.ssh/config'

# Show KVM and QEMU info
echo "KVM device info:"
ls -l /dev/kvm
echo "CPU virtualization support:"
grep -E 'vmx|svm' /proc/cpuinfo || echo "No CPU virtualization found!"
echo "Loaded kernel modules:"
# lsmod | grep -E 'kvm|virt'

# Start the runner
exec sudo -u runner /runner/start.sh