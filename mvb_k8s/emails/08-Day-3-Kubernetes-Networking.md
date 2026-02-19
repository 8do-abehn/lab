# Day 3: Kubernetes Networking

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Wed, 10 Dec 2025 15:29:05 +0000

---

Hey Adam,

​

You have a deployment running with multiple nginx pods.

But try to visit them in your browser. You can’t.

Those pods have IP addresses, but they’re internal to the
cluster. And even if you could reach them, what happens when a
pod dies and gets replaced? The new pod gets a new IP address.

This is the networking problem Kubernetes solves with Services.

​

The Problem: Pod IPs Are Ephemeral

​

Let’s see the current state:

​
kubectl get pods -o wide
​

The -o wide flag shows more columns, including IP addresses:

​
NAME READY STATUS IP NODE
my-app-6d9f9c6b9b-bm2qf 1/1 Running 10.42.0.15
rancher-desktop
my-app-6d9f9c6b9b-tnvrx 1/1 Running 10.42.0.16
rancher-desktop
​

Each pod has its own IP (10.42.0.x). These IPs work inside the
cluster - pods can talk to each other using them.

But here’s the problem:

* These IPs are only accessible from inside the cluster
* They change whenever a pod restarts
* You have multiple pods - which one do you connect to?

Imagine your frontend needs to talk to your backend. If you
hardcode the backend pod’s IP, your app breaks the moment that
pod restarts.

The Solution: Services

A Service is a stable endpoint that sits in front of your pods.

Instead of connecting to pod IPs directly, you connect to the
Service. The Service knows which pods belong to it (using labels)
and distributes traffic to them.

Think of it like a load balancer - one stable address that routes
to multiple backends.

Service Types

Kubernetes has several Service types. The three main ones:

ClusterIP (default)

Only accessible from inside the cluster. Gets a stable internal
IP.

Use case: Backend services that other pods need to reach.

NodePort

Opens a port on every node in the cluster. Accessible from
outside the cluster via :.

Use case: Quick external access for testing.

LoadBalancer

Creates an external load balancer (in cloud environments). Gets a
public IP address.

Use case: Production traffic from the internet.

​

For local development, we’ll use ClusterIP with port-forwarding.

This is the most common pattern for learning.

​

Create a Service

Make sure your deployment is running:

​
kubectl get deployment my-app
​

Now expose it:

​
kubectl expose deployment my-app --port=80 --target-port=80
​

What this does:

* Creates a Service called “my-app” (same name as the deployment)
* Listens on port 80
* Forwards traffic to port 80 on the pods

​

Check it:

​
kubectl get services
​

​
NAME TYPE CLUSTER-IP EXTERNAL-IP PORT(S)
AGE
kubernetes ClusterIP 10.43.0.1 443/TCP 2d
my-app ClusterIP 10.43.245.127 80/TCP 5s
​

Your service has a ClusterIP (10.43.245.127). This IP is stable -
it won’t change even if all the pods behind it are replaced.

​

How the Service Finds Pods

Services use label selectors to find their pods.

When you ran kubectl expose deployment my-app, Kubernetes
automatically configured the Service to select pods with the
label app=my-app.

See the details:

​
kubectl describe service my-app
​

Look for these lines:

​
Selector: app=my-app
Endpoints: 10.42.0.15:80,10.42.0.16:80
​

Selector is the label query used to find pods. Endpoints are the
actual pod IPs currently backing this service.

Delete a pod and run describe again. You’ll see the Endpoints
update automatically.

​

Accessing the Service

The ClusterIP is only reachable from inside the cluster. Your
laptop isn’t inside the cluster.

To access it from your browser, use port-forward:

​
kubectl port-forward service/my-app 8080:80
​

This creates a tunnel: - Your laptop’s port 8080 → Service port
80 → Pod port 80

Open your browser: http://localhost:8080

You should see “Welcome to nginx!”

​

What Just Happened

Let’s trace the path:

* Your browser requests localhost:8080
* kubectl forwards that to the my-app Service on port 80
* The Service picks one of its endpoint pods
* The request reaches nginx in that pod
* nginx returns the welcome page
* Response travels back through the tunnel

Keep the port-forward running. Open another terminal and delete a
pod:

​
kubectl delete pod CLICK HERE (
https://ed9688f7.click.convertkit-mail2.com/75u55z3wgdc2uk878zkbzhwe8n966bnh5oxrl/n2hohvhvr0g8d0t6/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
)to join.

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://ed9688f7.unsubscribe.convertkit-mail2.com/75u55z3wgdc2uk878zkbzhwe8n966bnh5oxrl
) | Update your profile (
https://preferences.convertkit-mail2.com/75u55z3wgdc2uk878zkbzhwe8n966bnh5oxrl
)
