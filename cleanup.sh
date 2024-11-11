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

LOGFILE="cleanup.log"
echo "Resetting Kubernetes and cleaning up resources..." | tee -a "$LOGFILE"

# Reset Kubernetes using kubeadm and log output
echo "Running kubeadm reset..." | tee -a "$LOGFILE"
if ! sudo kubeadm reset -f >> "$LOGFILE" 2>&1; then
    echo "kubeadm reset failed, proceeding with manual cleanup..." | tee -a "$LOGFILE"
fi

# Remove kubeconfig directory
echo "Removing .kube directory..." | tee -a "$LOGFILE"
sudo rm -rf $HOME/.kube >> "$LOGFILE" 2>&1

# Remove CNI network configurations
echo "Cleaning up CNI network configurations..." | tee -a "$LOGFILE"
sudo rm -rf /etc/cni/net.d/* >> "$LOGFILE" 2>&1

# Remove etcd data directory
echo "Removing etcd data directory..." | tee -a "$LOGFILE"
sudo rm -rf /var/lib/etcd/ >> "$LOGFILE" 2>&1

# Clean up flannel IP remnants
echo "Cleaning up flannel IP remnants..." | tee -a "$LOGFILE"
sudo rm -rf /var/lib/cni/* >> "$LOGFILE" 2>&1

echo "Kubernetes reset and cleanup completed." | tee -a "$LOGFILE"