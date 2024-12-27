#!/bin/bash

echo "=== System Info ==="
uname -a
echo

echo "=== KVM Status ==="
ls -l /dev/kvm
echo

echo "=== Libvirt Status ==="
systemctl status libvirtd || true
ls -l /var/run/libvirt/libvirt-sock
echo

echo "=== Network Status ==="
virsh net-list --all
echo

echo "=== VM Status ==="
virsh list --all
echo

echo "=== VM Logs ==="
cat /var/log/qemu/freebsd.log 2>/dev/null || echo "No VM log found"
echo

echo "=== Libvirt Logs ==="
cat /var/log/libvirt/libvirtd.log 2>/dev/null || echo "No libvirt log found"
echo

echo "=== CPU Info ==="
grep -E 'vmx|svm' /proc/cpuinfo || echo "No virtualization support found!"
echo

echo "=== Memory Info ==="
free -h
echo