# testbed-automator
`install.sh` : automates the deployment of a single-node k8s cluster, configures cluster, installs various CNIs, configures ovs bridges and sets everything up for deployment of 5G core.

`uninstall.sh`: reverses install.sh

# troubleshooting

## kudeadm init hangs

Check kubelet status
```bash
sudo systemctl status --no-pager --full kubelet.service
```

If you get error like the following:

> OCI runtime create failed: expected cgroupsPath to be of format \"slice:prefix:name\" for systemd cgroups, got \"/kubepods/burstable/..."

Then remove the containerd configuration and restart containerd.

```
sudo rm /etc/containerd/config.toml
systemctl restart containerd
```

## Error writing to crisocket
![](images/error-crisocket.png)

This can happen if you had a previous installation of Kubernetes.
Reset kubeadm and cleanup remnants of previous installation, as follows:
```
sudo kubeadm reset
sudo rm -rf $HOME/.kube
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/etcd/
```
Then run `install.sh` again. It after installation, kubernetes pods show as pending, do a reboot.