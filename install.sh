#!/bin/bash
#
# Description: This script is designed to deploy the 5G testbed at UWaterloo.
# Author: Niloy Saha
# Date: 24/10/2023
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

install-packages() {
  sudo apt-get update
  sudo apt-get install -y vim tmux git curl iproute2 iputils-ping iperf3 tcpdump python3-pip
  sudo pip3 install virtualenv
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


# Disable Swap
disable-swap() {
    cecho "GREEN" "Disabling swap ..."
    if [ -n "$(swapon -s)" ]; then
        # Swap is enabled, disable it
        sudo swapoff -a

        # Comment out the swap entry in /etc/fstab to disable it permanently
        sudo sed -i '/swap/ s/^/#/' /etc/fstab

        echo "Swap has been disabled and commented out in /etc/fstab."
    else
        echo "Swap is not enabled on this system."
    fi
}

disable-firewall() {
  cecho "YELLOW" "Disabling firewall ..."
  sudo ufw disable
}

# Install containerd as Kubernetes CRI
# Based on https://docs.docker.com/engine/install/ubuntu/
# Fixme: If containerd is not running with proper settings, it just checks if containerd is there and exits.
install-containerd() {
  if [ -x "$(command -v containerd)" ]
  then
          cecho "YELLOW" "Containerd is already installed."
  else
          cecho "GREEN" "Installing containerd ..."
          # Add Docker's official GPG key:
          sudo apt-get update
          sudo apt-get install ca-certificates curl gnupg
          sudo install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          sudo chmod a+r /etc/apt/keyrings/docker.gpg

          # Add the repository to Apt sources:
          echo \
            "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

          sudo apt-get update
          sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          sudo mkdir -p /etc/containerd
          sudo bash -c 'containerd config default > /etc/containerd/config.toml'
          sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
          sudo systemctl enable containerd
          sudo systemctl restart containerd
  fi

  # Check if Containerd is running
  if sudo systemctl is-active containerd &> /dev/null; then
    cecho "GREEN" "Containerd is running :)"
  else
    cecho "RED" "Containerd installation failed or is not running!"
  fi
}

# Setup K8s Networking
# Based on https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic
setup-k8s-networking() {
  cecho "GREEN" "Setting up Kubernetes networking ..."
  # Load required kernel modules
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

  sudo modprobe overlay
  sudo modprobe br_netfilter

  # Configure sysctl parameters for Kubernetes
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

  # Apply sysctl parameters without reboot
  sudo sysctl --system > /dev/null

}

# Install Kubernetes
install-k8s() {
  if [ -x "$(command -v kubectl)" ] && [ -x "$(command -v kubeadm)" ] && [ -x "$(command -v kubelet)" ]; then
    cecho "YELLOW" "Kubernetes components (kubectl, kubeadm, kubelet) are already installed."
  else
    cecho "GREEN" "Installing Kubernetes components (kubectl, kubeadm, kubelet) ..."
    sudo apt-get update
    # apt-transport-https may be a dummy package; if so, you can skip that package
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
  fi
}

create-k8s-cluster() {
  if [ -f "/etc/kubernetes/admin.conf" ]; then
    cecho "YELLOW" "A Kubernetes cluster already exists. Skipping cluster creation."
  else
    cecho "GREEN" "Creating k8s cluster ..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

    # Setup kubectl without sudo
    mkdir -p ${HOME}/.kube
    sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
    sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

    timer=60
    cecho "YELLOW" "Waiting $timer secs for cluster to be ready"
    timer-sec $timer

    # Remove NoSchedule taint from all nodes
    cecho "GREEN" "Allowing scheduling pods on master node ..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
  fi
}

# Install Flannel as CNI
install-cni() {
  if kubectl get pods -n kube-flannel -l app=flannel | grep -q '1/1'; then
    cecho "YELLOW" "Flannel is already running. Skipping installation."
  else
    cecho "GREEN" "Installing Flannel as primary CNI ..."
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    timer-sec 60
    kubectl wait pods -n kube-flannel  -l app=flannel --for condition=Ready --timeout=120s
  fi
}

# Install Multus as meta CNI
install-multus() {
  if kubectl get pods -n kube-system -l app=multus | grep -q '1/1'; then
    cecho "YELLOW" "Multus is already running. Skipping installation."
  else
    cecho "GREEN" "Installing Multus as meta CNI ..."
    git -C build/multus-cni pull || git clone https://github.com/k8snetworkplumbingwg/multus-cni.git build/multus-cni
    cd multus-cni
    cat ./deployments/multus-daemonset-thick.yml | kubectl apply -f -
    timer-sec 30
    kubectl wait pods -n kube-system  -l app=multus --for condition=Ready --timeout=120s
  fi
}


# Install Helm3
install-helm() {
  HELM_VERSION=$(helm version --short 2> /dev/null)

  if [[ "$HELM_VERSION" != *"v3"* ]]; then
    cecho "GREEN" "Helm 3 is not installed. Proceeding to install Helm ..."

    # Install Helm prerequisites
    curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes

    # Add Helm repository and install Helm
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
  else
    cecho "YELLOW" "Helm 3 is already installed."
  fi
}

install-openebs() {
  helm repo add openebs https://openebs.github.io/charts
  helm repo update
  helm install openebs --namespace openebs openebs/openebs --create-namespace

  # patch k8s storageclass to make openebs-hostpath as default
  kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
}

setup-ovs-cni() {
  # todo: install openvswitch, create bridges, install ovs cni
}

configure-open5gs() {
  # todo: setup venv, add admin account, insert subscribers
}

# run-as-root
install-packages
disable-swap
disable-firewall
setup-k8s-networking
install-containerd
install-k8s
create-k8s-cluster
install-cni
install-multus
install-helm
install-openebs
