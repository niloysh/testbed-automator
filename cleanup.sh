#!/bin/bash
echo "Removing OpenVSwitch"
sudo rm -rf /etc/openvswitch

echo "Resetting Kubernetes and cleaning up resources..."

systemctl stop kubelet

echo "Running kubeadm reset..."
if ! sudo kubeadm reset -f; then
    echo "kubeadm reset failed, proceeding with manual cleanup..."
fi

echo "Removing .kube directory..."
sudo rm -rf $HOME/.kube

echo "Removing etcd data directory..."
sudo rm -rf /var/lib/etcd/

echo "Cleaning up CNI network configurations..."
sudo rm -rf /etc/cni/net.d/*

echo "Cleaning up flannel IP remnants..."
sudo rm -rf /var/lib/cni/*

echo "Kubernetes reset and cleanup completed."


ls /var/lib/cni/networks/
mv /var/lib/cni/networks /var/lib/cni/networks.bak
mkdir /var/lib/cni/networks

systemctl start containerd
systemctl start kubelet
