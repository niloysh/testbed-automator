#!/bin/bash
#
# Description: This script is designed to uninstall the 5G testbed at UWaterloo
# deployed using install.sh
# Author: Niloy Saha
# Date: 27/1/2024
# Version: 1.0
# Usage: Please ensure that you run this script as ROOT or with ROOT permissions.
# Notes: This script is designed for use with Ubuntu 22.04.
# ==============================================================================

run-as-root(){
  if [ "$EUID" -ne 0 ]
  then cecho "RED" "This script must be run as ROOT"
  exit
  fi
}

timer-sec(){
  secs=$((${1}))
  while [ $secs -gt 0 ]; do
    echo -ne "Waiting for $secs\033[0K seconds ...\r"
    sleep 1
    : $((secs--))
  done
}

# Based on https://stackoverflow.com/a/53463162/9346339
cecho(){
    RED="\033[0;31m"
    GREEN="\033[0;32m"  # <-- [0 means not bold
    YELLOW="\033[1;33m" # <-- [1 means bold
    CYAN="\033[1;36m"
    # ... Add more colors if you like

    NC="\033[0m" # No Color

    # printf "${(P)1}${2} ${NC}\n" # <-- zsh
    printf "${!1}${2} ${NC}\n" # <-- bash
}


uninstall_docker() {
  cecho "RED" "Uninstalling docker ..."
  if [ -x "$(command -v docker)" ]; then
    sudo docker image prune -a
    sudo systemctl restart docker
    sudo apt purge -y docker-engine docker docker.io docker-ce docker-ce-cli containerd containerd.io runc --allow-change-held-packages
  else
    cecho "YELLOW" "Docker is not installed."
  fi
}

uninstall_containerd() {
  cecho "RED" "Uninstalling containerd ..."
  if [ -x "$(command -v containerd)" ]; then
    sudo systemctl stop containerd
    sudo apt-get remove --purge -y containerd.io docker-ce docker-ce-cli
    sudo rm -rf /etc/containerd
    cecho "GREEN" "Containerd and related packages have been uninstalled."
  else
    cecho "YELLOW" "Containerd is not installed."
  fi
}


uninstall_k8s() {
  cecho "RED" "Uninstalling Kubernetes components (kubectl, kubeadm, kubelet)..."
  if [ -x "$(command -v kubectl)" ] && [ -x "$(command -v kubeadm)" ] && [ -x "$(command -v kubelet)" ]; then
    sudo apt-get remove --purge -y --allow-change-held-packages kubeadm kubectl kubelet kubernetes-cni kube* 
    cecho "GREEN" "Kubernetes components have been deleted."
  else
    cecho "YELLOW" "Kubernetes components (kubectl, kubeadm, kubelet) are not installed."
  fi

}

reset_k8s_cluster(){
  cecho "RED" "Deleting Kubernetes cluster..."
  if [ -f "/etc/kubernetes/admin.conf" ]; then
    sudo kubeadm reset -f -q
    cecho "GREEN" "Kubernetes cluster has been deleted."
  else
    cecho "YELLOW" "Kubernetes cluster is not running."
  fi

  sudo rm -rf /etc/kubernetes
  sudo rm -rf ${HOME}/.kube
  sudo rm -rf /var/lib/kubelet/
  sudo rm -rf /var/lib/etcd
  sudo rm -rf 
  sudo rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/lib/etcd2/ /var/run/kubernetes 
  sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock
  sudo rm -f /etc/apparmor.d/docker /etc/systemd/system/etcd* 
}

uninstall_cni() {
  cecho "RED" "Uninstalling Flannel CNI ..."
  if kubectl get pods -n kube-flannel -l app=flannel | grep -q '1/1'; then
    kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    cecho "GREEN" "Uninstalled Flannel CNI."
  else 
    cecho "YELLOW" "Flannel CNI is not installed."
  fi
  cecho "RED" "Removing CNI configuration files ..."
  sudo rm -rf /etc/cni
}

uninstall_helm() {
    cecho "RED" "Removing Helm3"
    if [ -x "$(command -v helm)" ]; then
        sudo apt-get remove --purge -y helm
        cecho "GREEN" "Helm3 has been removed."
    else
        cecho "YELLOW" "Helm3 is not installed"
    fi
}

uninstall_openebs() {
  cecho "RED" "Removing openebs ..."
  if kubectl get namespace | grep -q openebs; then
    helm uninstall openebs --namespace openebs
    kubectl delete ns openebs
  else
    cecho "YELLOW" "OpenEBS is not installed."
    return
  fi

  cecho "GREEN" "OpenEBS has been uninstalled."
}

remove_ovs_cni() {
  cecho "RED" "Removing OVS CNI setup..."

  if kubectl get namespace | grep -q cluster-network-addons; then
    cecho "RED" "Removing cluster-network-addons ..."
    kubectl delete -f https://github.com/kubevirt/cluster-network-addons-operator/releases/download/v0.89.1/namespace.yaml
    cecho "GREEN" "OVS CNI has been removed."
  else
    cecho "YELLOW" "OVS CNI is not installed"
  fi

  if [ -x "$(command -v ovs-vsctl)" ]; then
    cecho "RED" "Removing OpenVSwitch"
    sudo apt-get remove --purge -y openvswitch-switch
    cecho "GREEN" "OpenVSwitch has been removed."
  else
    cecho "YELLOW" "OpenVSwitch is not installed"
  fi
}

uninstall_multus() {
  cecho "RED" "Uninstalling multus ..."
  if kubectl get pods -n kube-system -l app=multus | grep -q '1/1'; then
    cd build/multus-cni
    cat ./deployments/multus-daemonset.yml | kubectl delete -f -
    cecho "GREEN" "Uninstalled multus."
  else
    cecho "YELLOW" "Multus is not installed."
  fi
}

clear-remnants() {
  cecho "RED" "Cleaning up build directories and redundant packages ..."
  sudo rm -rf build
  sudo apt-get -y autoremove
}

remove_ovs_cni
uninstall_openebs
uninstall_helm
uninstall_multus
uninstall_cni
reset_k8s_cluster
uninstall_k8s
uninstall_containerd
uninstall_docker
clear-remnants


SCRIPT_DIRECTORY="$(dirname $(realpath "$0"))"
source $SCRIPT_DIRECTORY/cleanup.sh

cecho "GREEN" "Uninstallation completed."
