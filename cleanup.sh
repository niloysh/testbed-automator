#!/bin/bash
#
# Description: Helper script to cleanup Kubernetes remnants from previous install
# of testbed-automator
# Author: Niloy Saha
# Date: 29/10/2024
# Version: 1.0
# Usage: 
# - Please ensure that you run this script as ROOT or with ROOT permissions.
# - Use after running uninstall.sh
# Notes: This script is designed for use with Ubuntu 22.04.
# Reset Kubernetes using kubeadm
#!/bin/bash
echo "Resetting Kubernetes and cleaning up resources..."

# Reset Kubernetes using kubeadm and log output
echo "Running kubeadm reset..."
if ! sudo kubeadm reset -f; then
    echo "kubeadm reset failed, proceeding with manual cleanup..."
fi

# Remove kubeconfig directory
echo "Removing .kube directory..."
sudo rm -rf $HOME/.kube

# Remove CNI network configurations
echo "Cleaning up CNI network configurations..."
sudo rm -rf /etc/cni/net.d/*

# Remove etcd data directory
echo "Removing etcd data directory..."
sudo rm -rf /var/lib/etcd/

# Clean up flannel IP remnants
echo "Cleaning up flannel IP remnants..."
sudo rm -rf /var/lib/cni/*

echo "Kubernetes reset and cleanup completed."