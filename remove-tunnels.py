from arrow import get
import paramiko
import getpass
import subprocess
import argparse
import json
import hashlib


def get_kubernetes_nodes():
    """
    Use kubectl to get the list of nodes and their internal IPs.
    """
    try:
        result = subprocess.run(
            ["kubectl", "get", "nodes", "-o", "json"],
            check=True,
            capture_output=True,
            text=True,
        )
        nodes_info = json.loads(result.stdout)
        nodes = {}
        for node in nodes_info["items"]:
            node_name = node["metadata"]["name"]
            internal_ip = next(addr["address"] for addr in node["status"]["addresses"] if addr["type"] == "InternalIP")
            nodes[node_name] = internal_ip
        return nodes
    except subprocess.CalledProcessError as e:
        print(f"Error fetching nodes: {e}")
        return {}


def ssh_run_sudo_command(host, port, username, password, command):
    """
    SSH to a remote node and run a sudo command, prompting the user for the sudo password.

    Args:
        host (str): The IP or hostname of the remote node.
        port (int): The SSH port (default is 22).
        username (str): The SSH username.
        command (str): The command to run with sudo privileges.
    """
    try:

        # Create an SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname=host, port=port, username=username, password=password)

        # Use sudo to run the command
        sudo_command = f"echo {password} | sudo -S {command}"
        stdin, stdout, stderr = ssh.exec_command(sudo_command, get_pty=True)

        # Read output and error
        output = stdout.read().decode()
        error = stderr.read().decode()

        return output, error

    except paramiko.SSHException as e:
        print(f"SSH connection failed: {e}")
    finally:
        ssh.close()


def remove_vxlan(master_node, master_ip, worker_nodes, ovs_bridge):

    vxlan_keys = {}
    for bridge in ovs_bridge:
        # Derive a consistent VXLAN key from the bridge name (hashed)
        vxlan_key = int(hashlib.md5(bridge.encode()).hexdigest()[:4], 16)
        vxlan_keys[bridge] = vxlan_key

    username = getpass.getuser()
    print("Username: ", username)
    password = getpass.getpass(prompt=f"Enter sudo password: ")
    print("Note: This script assumes the same username and sudo password on all nodes.")

    for worker_name, worker_ip in worker_nodes.items():
        print(f"*" * 50)
        print(f"Removing VXLAN tunnel between master node and worker node {worker_name} ({worker_ip})")

        for ovs_bridge, vxlan_key in vxlan_keys.items():
            vxlan_port = f"vxlan-{worker_name}-{ovs_bridge}"

            cmd = f"ovs-vsctl del-port {ovs_bridge} {vxlan_port} 2>/dev/null || true"
            output, error = ssh_run_sudo_command(master_ip, 22, username, password, cmd)

            cmd = f"ovs-vsctl del-port {ovs_bridge} {vxlan_port} 2>/dev/null || true"
            output, error = ssh_run_sudo_command(worker_ip, 22, username, password, cmd)


if __name__ == "__main__":
    args = argparse.ArgumentParser(description="Setup VXLAN tunnels between Kubernetes nodes for OVS-CNI")
    args.add_argument("--ovs-bridges", nargs="+", default=["n2br", "n3br", "n4br"])
    args = args.parse_args()

    nodes = get_kubernetes_nodes()
    if not nodes:
        print("No nodes found!")
        exit(1)

    # Get the master node and its IP
    master_node = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()
    master_ip = nodes.pop(master_node, None)

    if not master_ip:
        print("Master node not found in node list!")
        exit(1)

    else:
        print(f"Master node: {master_node} ({master_ip})")
        print("Worker nodes:")
        for node, ip in nodes.items():
            print(f"  {node}: {ip}")

    remove_vxlan(master_node, master_ip, nodes, args.ovs_bridges)
