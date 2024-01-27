# testbed-automator



`install.sh` : automates the deployment of a single-node k8s cluster, configures cluster, installs various CNIs, configures ovs bridges and sets everything up for deployment of 5G core.

`install-open5gs-k8s`: Pulls from the open5gs-k8s repo and install 5G core network consisting of two slices. Then it spins up a gNB and 3 UEs, one for each slice.

`uninstall.sh`: reverses install.sh
