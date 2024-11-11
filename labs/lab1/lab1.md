# Lab 1: Kubernetes Basics

In this lab, you’ll learn how to deploy containers, work with namespaces, set up services, use ConfigMaps, and create deployments in Kubernetes. These foundational skills will prepare you for deploying and managing applications, including those used in our 5G core network deployment.

**Estimated Time**: 25m


## 0. Prerequisites
Make sure that you have successfully deployed the testbed-automator script as outlined in the [Quick Start](../../README.md#quick-start).

## 1. Deploy a simple Ubuntu Container
In this part of the lab, we will deploy a simple Ubuntu container from a Docker image.
A simple Ubuntu container can be very helpful in debugging; it can easily let us install whatever tools we wish with apt install.
For this lab, we will utilize the `ghcr.io/niloysh/toolbox:v1.0.0` image, which is an Ubuntu-based image preloaded with a selection of commonly used tools, including ping, net-tools, and more.

### The YAML manifest file
The following YAML will deploy a Pod with a container running the Ubuntu docker image that sleeps for one week. We need to actually make the container **do something**, else it will immediately exit; hence the we make it sleep for some time. 

![pod](../../images/pod.png)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu
  labels:
    app: ubuntu
spec:
  containers:
  - image: ghcr.io/niloysh/toolbox:v1.0.0
    command:
      - "sleep"
      - "604800"
    imagePullPolicy: IfNotPresent
    name: ubuntu
  restartPolicy: Always
```

The `ubuntu-pod.yaml` file contains the YAML code above. We can deploy this as follows
```bash
cd labs
kubectl apply -f ubuntu-pod.yaml
```
This action may take a bit of time to download the Ubuntu image from Dockerhub and then deploy the pod.
To check the status of your pod, you can use `kubectl get pods`.
Eventually the status should show up as `Running.`

```bash
kubectl get pods
```
You should see output as below

```
NAME     READY   STATUS    RESTARTS   AGE
ubuntu   1/1     Running   0          66s
```

## Using the pod
We can start up an interactive shell in the container as follows:
```bash
kubectl exec -it ubuntu -- /bin/bash

root@ubuntu:/# 
```
Now, we can install any tools we like! For example, we can install the iputils-ping and curl packages via the following.
```
apt-get update -y && apt-get install iputils-ping curl
```
This will allow us to any IP address to check connectivity. For example,
```bash
root@ubuntu:/# ping 8.8.8.8 -c 2
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=61 time=4.62 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=61 time=4.94 ms

--- 8.8.8.8 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1003ms
rtt min/avg/max/mdev = 4.619/4.781/4.943/0.162 ms
```

## 2. Introduction to Namespaces

Namespaces allow you to organize and isolate resources within a Kubernetes cluster. Think of them as “virtual clusters” inside your main cluster, letting you separate environments or applications.

### 2a. Create a Namespace

First, let’s create a namespace called workshop where we can deploy our resources without cluttering the default namespace.

To create the namespace, use the following command:
```bash
kubectl create namespace workshop
```
Verify it’s been created by listing namespaces:

```bash
kubectl get namespaces
```
### 2b. Deploy the Ubuntu Pod in a Namespace
Now, let’s modify the Ubuntu pod manifest to deploy it in our new workshop namespace. 

![namespace](../../images/namespace.png)


Let's look at the `ubuntu-ws.yaml` file:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-ws
  namespace: workshop
  labels:
    app: ubuntu
spec:
  containers:
  - image: ghcr.io/niloysh/toolbox:v1.0.0
    command:
      - "sleep"
      - "604800"
    imagePullPolicy: IfNotPresent
    name: ubuntu
  restartPolicy: Always
```

We can apply the `ubuntu-ws.yaml` manifest as follows:
```bash
kubectl apply -f ubuntu-ws.yaml
```

To check the status of the pod in the workshop namespace:
```bash
kubectl get pods -n workshop
```

## 3. Introduction to Services
Services allow you to expose a set of Pods as a network service, making it possible for other resources to communicate with them. This can be used to expose an application within or outside the cluster. In our 5G core network, network functions communicate with each other using services.

![service](../../images/service.png)

### 3a. Deploy an nginx Pod
To understand services, first let's deploy an nginx pod that will serve HTTP traffic on port 80. This will allow us to test connectivity from other pods such as the ubuntu pod we deployed earlier.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
  namespace: workshop
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
  restartPolicy: Always
```

The `nginx-pod.yaml` file contains the yaml above. Apply this with:
```
kubectl apply -f nginx-pod.yaml
```
Check the status of the nginx pod to make sure it is running.
```bash
kubectl get pods -n workshop
```
You should see
```
NAME        READY   STATUS    RESTARTS   AGE
nginx       1/1     Running   0          92s
ubuntu-ws   1/1     Running   0          14m
```

### 3b. Expose the Nginx Pod with a Service
Next, let’s expose the Nginx pod with a ClusterIP service (the default type) to allow other pods in the cluster to reach it.
Here’s the YAML manifest for a ClusterIP service that will expose our Nginx pod internally within the workshop namespace:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: workshop
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```
The `nginx-service.yaml` file contains the above yaml. We can apply it as follows:
```bash
kubectl apply -f nginx-service.yaml
```
To confirm that the service is running, check the services in the workshop namespace:
```bash
kubectl get services -n workshop
```
You should see output as follows:
```
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx-service   ClusterIP   10.108.24.210   <none>        80/TCP    8s
```
We can see from the output that port 80 inside the pod is exposed to the cluster.

### Verify the Service Connection
To test the service, you can use another pod to curl the nginx-service and check if it’s accessible. 
We can use our Ubuntu pod, for example, to interact with the nginx service. Open up a shell in the ubuntu pod in the workshop namespace, install curl, and then use curl to test the nginx-service.

```bash
kubectl exec -n workshop -it ubuntu -- /bin/bash

apt update && apt install curl
curl nginx-service:80
```

## 4. ConfigMaps

ConfigMaps are used to store configuration data separately from application code. They allow you to manage environment-specific settings without altering your pod definitions.
We will use ConfigMaps a lot to store configurations for each network function (e.g., SMF, AMF) when we deploy our 5G core.

![configmap](../../images/configmap.png)

### 3a. Create a ConfigMap

Let’s create a ConfigMap to store environment variables for our Ubuntu pod. This will store some basic configuration data, like a message and a sleep duration.

The `ubuntu-configmap.yaml` with the contains the following content:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ubuntu-config
  namespace: workshop
data:
  MESSAGE: "Hello from ConfigMap!"
  SLEEP_DURATION: "604800"
```
We can apply the ConfigMap as follows:
```bash
kubectl apply -f ubuntu-configmap.yaml
```

### 3b. Use ConfigMap in a Pod

Now, let's create a new pod that will use this configmap. The pod will read the values of MESSAGE and SLEEP_DURATION as environment variables.

Look at the `ubuntu-ws-cfg.yaml` file which contains the following content:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-ws-cfg
  namespace: workshop
  labels:
    app: ubuntu
spec:
  containers:
  - name: ubuntu
    image: ghcr.io/niloysh/toolbox:v1.0.0
    command: ["/bin/sh", "-c", "echo $MESSAGE && sleep $SLEEP_DURATION"]
    env:
    - name: MESSAGE
      valueFrom:
        configMapKeyRef:
          name: ubuntu-config
          key: MESSAGE
    - name: SLEEP_DURATION
      valueFrom:
        configMapKeyRef:
          name: ubuntu-config
          key: SLEEP_DURATION
  restartPolicy: Always
```
We can deploy this as follows:
```bash
kubectl apply -f ubuntu-ws-cfg.yaml
```

Verify the pod’s logs to see the ConfigMap values being used:
```bash
kubectl logs ubuntu-ws-cfg -n workshop
```

## 5. Deployments
Deployments manage a set of identical Pods (replicas) for scalability, high availability, and ease of updates.

![deployment](../../images/deployment.png)

### Create an nginx Deployment
Let’s create a Deployment to manage multiple instances of an nginx container. This Deployment will run two replicas of nginx.

Look at the `nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: workshop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

Apply the Deployment:

```bash
kubectl apply -f nginx-deployment.yaml
```

Check the status of the Deployment and Pods it manages:
```bash
kubectl get deployments -n workshop
kubectl get pods -l app=nginx -n workshop
```

Congratulations, you've now familiar with some of the basic components of Kubernetes we will use for our 5G network deployment.

When you're all done, continue to the [next lab](../lab2/lab2.md) of this workshop.