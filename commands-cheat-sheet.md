---
marp: true
theme: default
paginate: true
# size: 4:3
--- 
# Workshop Commands Cheat Sheet (1/2)

**Linux Commands**
- `cd /path/to/dir` - Change directory.
- `cd ~` - Change directory to home directory.
- `cd ..` - Go back one directory.
- `code /path/to/dir` - Open directory in the VSCode editor.
- `code .` - Open current directory `.` in VSCode.
- `ip a` - Show IP addresses of all network interfaces.
- `ping address` - Check connectivity to an address.
- `ping -I uesimtun0 address` - Check connectivity to an address from UEs.
- `curl http://url` - Fetch data from URL.

---
# Workshop Commands Cheat Sheet (2/2)

**Kubectl Commands**

- `kubectl get pods` - List all pods in the default namespace.
- `kubectl get pods -n namespace` - List all pods in a specific namespace.
- `kubectl get namespaces` - Lists all namespaces.
- `kubectl exec -it pod_name -n namespace -- command` - Execute a command in a specific pod in a namespace.
- `kubectl logs pod_name -n namespace` - Show logs from a pod in a specific namespace.
- `kubectl apply -f file.yaml` - Deploy a Kubernetes resource from a YAML file.
- `kubectl delete -f file.yaml` - Delete deployed resources using a YAML file.
- `kubectl get services -n namespace` - List all services in a specific namespace.