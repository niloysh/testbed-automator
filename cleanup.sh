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
# ==============================================================================
sudo kubeadm reset
sudo rm -rf $HOME/.kube
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/etcd/

# clean up flannel IP remnants
# when pods complain "ran out of IP range"
sudo rm -rf /var/lib/cni/*  