# Your Kubernetes journey starts now

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Mon, 08 Dec 2025 20:16:21 +0000

---

Hey Adam,

​

Welcome to the 7-day Kubernetes quickstart.

By the end of this week, you’ll have:

* A real Kubernetes cluster running on your machine
* Deployed multiple applications
* Built a self-hosted bookmark manager you’ll actually use
* Understood pods, deployments, services, and persistent storage

No fluff. No theory overload. Just hands-on learning.

But before we touch any tools, let me explain what Kubernetes
actually is. Most tutorials skip this and leave you confused.

The Problem Kubernetes Solves

Imagine you’re running a web application. It lives on a server.
Life is simple.

Then your app gets popular. One server can’t handle the traffic.
So you add more servers. Now you have 10 servers running your
app.

Questions start piling up:

* How do you deploy updates to all 10 servers?
* What happens when one server crashes at 3am?
* How do you scale up during peak hours and scale down at night?
* How do servers know about each other?
* How does traffic get distributed between them?

You could write scripts. Use Ansible. Hire someone to babysit
servers.

Or you could use Kubernetes.

Kubernetes is a container orchestrator. You tell it “I want 10
copies of my app running” and it figures out the rest. It
distributes them across servers. It restarts them when they
crash. It scales them up and down based on demand.

You declare what you want. Kubernetes makes it happen.

That’s the core idea. Everything else is details.

Why Containers?

Kubernetes runs containers, not regular applications.

A container is a lightweight, isolated package that includes your
application and everything it needs to run. Code, libraries,
dependencies, configuration. All bundled together.

Think of it like shipping containers on a cargo ship. Before
shipping containers existed, loading a ship was chaos. Different
sized boxes, barrels, crates. Every port had different equipment.

Then someone invented the standard shipping container. Now any
crane at any port can handle any container. The contents don’t
matter. The interface is standardized.

Software containers work the same way. Your app might need Python
3.12, specific libraries, certain environment variables. Instead
of installing all that on every server, you package it into a
container. That container runs the same way everywhere. Your
laptop, a test server, production, the cloud.

Kubernetes doesn’t care what’s inside the container. It just
knows how to run containers, restart them, scale them, and
connect them together.

The Kubernetes Cluster

A Kubernetes cluster is a set of machines working together.

There are two types of machines:

Control Plane

The brain. It stores the cluster state, makes scheduling
decisions, and responds to your commands. In production, you
usually have 3 control plane nodes for redundancy.

Worker Nodes

The muscle. These are the machines that actually run your
containers. You might have 3, 30, or 300 worker nodes depending
on your scale.

When you run a command like “deploy my app with 5 copies,” the
control plane receives that request, decides which worker nodes
have capacity, and tells those nodes to start containers.

For learning, you only need one machine that acts as both control
plane and worker. That’s what we’re setting up today.

Let’s Get Started: Install Rancher Desktop

Rancher Desktop is a free, open-source tool that creates a
complete Kubernetes cluster on your laptop.

I’ve taught Kubernetes to over 1,000 people. I’ve tested every
local Kubernetes option out there. Minikube, Kind, Docker
Desktop, K3d, MicroK8s. After hundreds of hours of research and
troubleshooting student issues, Rancher Desktop is what I
recommend.

Here’s why:

* One-click install with no complex configuration
* Works everywhere including Windows, Mac (including Apple
Silicon), and Linux
* Free forever with no license costs or enterprise upsells
* Uses K3s which is a lightweight but fully-compliant Kubernetes
distribution
* Includes kubectl so you have the command-line tool you need
* Handles the VM by creating and managing the Linux virtual
machine for you

Step 1: Download and Install

Go to https://rancherdesktop.io (
https://click.convertkit-mail2.com/0vuoo9zlr0hguox5x7zclhvzgdx55snh9x384/vqh3hrhogl3wnwcg/aHR0cHM6Ly9yYW5jaGVyZGVza3RvcC5pbw==
)​

Download the version for your operating system. Install it like
any other application.

When you first launch it, Rancher Desktop will:

1. Create a Linux virtual machine on your computer

2. Install K3s (Kubernetes) inside that VM

3. Configure kubectl to talk to your new cluster

4. Start all the necessary system components

​

This takes a few minutes. You’ll see a progress indicator. Wait
until you see a green checkmark. That means your cluster is
ready.

Step 2: Verify Your Cluster

Open your terminal:

- Mac: Terminal or iTerm

- Windows: PowerShell (not Command Prompt)

- Linux: Your terminal of choice

​

Run this command:

​
kubectl get nodes
​

You should see output like:

​
NAME STATUS ROLES AGE
VERSION
rancher-desktop Ready control-plane,master 5m
v1.34.3+k3s1
​

Let’s break this down:

* NAME: The name of your node (machine)
* STATUS: “Ready” means it’s healthy and can run workloads
* ROLES: This node is both control-plane and master (same thing,
different terminology)
* AGE: How long the node has been running
* VERSION: The Kubernetes version (K3s in this case)

If you see “Ready” then congratulations. You have a working
Kubernetes cluster.

Troubleshooting

If you get “command not found: kubectl”:

Rancher Desktop needs to add kubectl to your system PATH. Go to
Rancher Desktop, then Preferences, then Application, then Path.

Make sure it’s set to “Automatic” or manually add the path to
your shell configuration. Then restart your terminal.

If the node shows “NotReady”:

The cluster might still be starting up. Wait another minute and
try again. If it persists, try going to Rancher Desktop, then
Troubleshooting, then Reset Kubernetes.

If you get “connection refused”:

Rancher Desktop isn’t running. Open the app and wait for the
green checkmark.

​

Step 3: Explore Your Cluster

Let’s run a few more commands to understand what we’re working
with.

​

See all pods running in the cluster:

​
kubectl get pods -A
​

The -A flag means “all namespaces.” You’ll see system pods that
Kubernetes needs to function:

​
NAMESPACE NAME READY
STATUS
kube-system coredns-59b4f5bbd5-xxxxx 1/1
Running
kube-system local-path-provisioner-6c86858495-xxxxx 1/1
Running
kube-system metrics-server-67c658944b-xxxxx 1/1
Running
kube-system svclb-traefik-xxxxx 2/2
Running
kube-system traefik-f4564c4f4-xxxxx 1/1
Running
​

Don’t worry about understanding all of these yet. Just know
they’re system components:

- coredns: Handles DNS inside the cluster

- traefik: An ingress controller for routing traffic
- metrics-server: Collects resource usage data

- local-path-provisioner: Handles storage

​

See what’s in the default namespace:

​
kubectl get pods
​

You’ll see “No resources found in default namespace.” That’s
expected. We haven’t deployed anything yet.

​

Step 4: Deploy Your First Pod

Now let’s deploy something.

Run this:

​
kubectl run my-nginx --image=nginx
​

What just happened?

* You told Kubernetes “create a pod called my-nginx using the
nginx image”
* Kubernetes pulled the nginx container image from Docker Hub
* It created a pod and started the container inside it
* The nginx web server is now running

​

Check it:

​
kubectl get pods
​

​
NAME READY STATUS RESTARTS AGE
my-nginx 1/1 Running 0 30s
​

READY 1/1 means 1 out of 1 containers in the pod are ready.

STATUS Running means the pod is healthy.

RESTARTS 0 means it hasn’t crashed.

​

Step 5: Explore Your Pod

Let’s learn more about this pod.

Get detailed information:

​
kubectl describe pod my-nginx
​

This outputs a lot. Key sections:

* Containers: Shows the nginx container, its image, and state
* Conditions: Shows if the pod is scheduled, initialized, and
ready
* Events: Shows what happened like image pulled, container
started, etc.

​

See the logs:

​
kubectl logs my-nginx
​

This shows whatever nginx is outputting. Not much yet since no
one is visiting it.

​

Execute a command inside the container:

​
kubectl exec -it my-nginx -- /bin/bash
​

You’re now inside the container. You can look around:

​
ls /usr/share/nginx/html
cat /usr/share/nginx/html/index.html
exit
​

That index.html is the default nginx welcome page.

Step 6: Clean Up

Delete the pod:

​
kubectl delete pod my-nginx
​

Verify it’s gone:

​
kubectl get pods
​

“No resources found in default namespace.”

What You Learned Today

* Kubernetes is a container orchestrator. You declare what you
want, it makes it happen
* Containers are portable, isolated packages for running
applications
* A cluster has control plane nodes (brain) and worker nodes
(muscle)
* kubectl is your command-line tool for talking to Kubernetes
* A pod is the smallest unit in Kubernetes. It’s a wrapper around
one or more containers
* Basic commands: kubectl get, kubectl describe, kubectl logs,
kubectl exec, kubectl delete

Tomorrow, we level up. Instead of a single pod that disappears
when deleted, we’ll create deployments and watch Kubernetes
automatically heal when things break.

This is where it gets fun.

Mischa

​

P.S. If you’re serious about landing a DevOps job, this free
course is just the starting point. Inside KubeCraft, I have 50+
hours of production-grade projects, Weekly coaching calls, and a
community of 800+ engineers. Over 1,000 people have used this
system to land roles at Google, Microsoft, and Amazon. CLICK HERE
(
https://click.convertkit-mail2.com/0vuoo9zlr0hguox5x7zclhvzgdx55snh9x384/l2hehmhlrevxodf6/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
) to apply and see if you qualify.

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://unsubscribe.convertkit-mail2.com/0vuoo9zlr0hguox5x7zclhvzgdx55snh9x384
) | Update your profile (
https://preferences.convertkit-mail2.com/0vuoo9zlr0hguox5x7zclhvzgdx55snh9x384
)
