# Day 5: Deploy something you’ll actually use

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Fri, 12 Dec 2025 15:29:14 +0000

---

Hey Adam,

Let’s be honest.

Deploying nginx over and over gets boring. It doesn’t stick.

You do the tutorial, close your laptop, and forget everything by
next week.

Today we change that.

We’re deploying Linkding (
https://ed9688f7.click.convertkit-mail2.com/38u77drlv9hduorlr0pcrh4qgw2nns7h6rqzn/n2hohvhvr9xrqof6/aHR0cHM6Ly9naXRodWIuY29tL3Npc3NicnVlY2tlci9saW5rZGluZw==
), a self-hosted bookmark manager that you’ll actually use.

I’ve been running Linkding on my own Kubernetes cluster for over
a year. It’s genuinely useful:

* Save bookmarks from any browser with a browser extension
* Access them from any device: phone, tablet, other computers
* Never lose a link again
* Search through all your bookmarks instantly
* Your data stays on YOUR infrastructure, not some company’s
server

This is what self-hosting on Kubernetes looks like. Real
applications. Real value.

And unlike nginx demos, you’ll want to keep this running.

What We’re Building

By the end of tomorrow, you’ll have:

* Linkding running in its own namespace
* Persistent storage so your bookmarks survive restarts
* A service exposing the application
* A working bookmark manager you can use daily

Today we get Linkding running. Tomorrow we add persistent
storage.

Let’s go.

Namespaces: Organizing Your Cluster

Before we deploy, let’s learn about namespaces.

A namespace is a way to organize resources in your cluster. Think
of it like folders on your computer.

Without namespaces, everything lives in the “default” namespace.
That gets messy when you have multiple applications.

With namespaces:

* Each application gets its own space
* Resource names only need to be unique within a namespace
* You can set resource quotas per namespace
* You can control access per namespace

See existing namespaces:

​
kubectl get namespaces
​

​
NAME STATUS AGE
default Active 3d
kube-system Active 3d
kube-public Active 3d
kube-node-lease Active 3d
​

default is where resources go if you don’t specify a namespace.

kube-system contains system components (DNS, metrics, etc.).

kube-public holds publicly accessible data (rarely used).

kube-node-lease stores node heartbeat data.

​

(Don't worry if this list doesn't match your setup. It can vary
from cluster to cluster.)

​

Let’s create a namespace for Linkding:

​
kubectl create namespace linkding
​

Verify:

​
kubectl get namespace linkding
​

​
NAME STATUS AGE
linkding Active 5s
​

Setting Your Default Namespace

Typing -n linkding on every command gets tedious. Let’s set it as
the default:

​
kubectl config set-context --current --namespace=linkding
​

Now commands default to the linkding namespace:

​
kubectl get pods
​

​
No resources found in linkding namespace.
​

See? It’s looking in linkding, not default.

​

To switch back to default later:

​
kubectl config set-context --current --namespace=default
​

But for now, stay in linkding.

​

The Linkding Container Image

Linkding is packaged as a container image available on Docker
Hub:

​
sissbruecker/linkding
​

The image contains a Python web application, a SQLite database
(by default), and all dependencies pre-installed.

You don’t need to build anything. Just tell Kubernetes to run
this image.

​

Creating the Deployment YAML

Let’s build our YAML file step by step.

Create a file called linkding.yaml:

​

yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: linkding
namespace: linkding
labels:
app: linkding
spec:
replicas: 1
selector:
matchLabels:
app: linkding
template:
metadata:
labels:
app: linkding
spec:
containers:
- name: linkding
image: sissbruecker/linkding:latest
ports:
- containerPort: 9090
env:
- name: LD_SUPERUSER_NAME
value: "admin"
- name: LD_SUPERUSER_PASSWORD
value: "changeme123"

Let me explain what’s new here:

namespace: linkding

This deployment lives in the linkding namespace.

replicas: 1

We only need one instance. Linkding uses SQLite by default, which
doesn’t support multiple writers.

containerPort: 9090

Linkding listens on port 9090 inside the container.

env:

Environment variables passed to the container. Linkding uses
these to configure the application:

LD_SUPERUSER_NAME sets the admin username.

LD_SUPERUSER_PASSWORD sets the admin password.

Important: In production, you’d never put passwords in plain
YAML. You’d use Kubernetes Secrets. But for learning, this works.

​

Adding the Service

Add a Service to the same file. Use --- to separate resources:

yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: linkding
namespace: linkding
labels:
app: linkding
spec:
replicas: 1
selector:
matchLabels:
app: linkding
template:
metadata:
labels:
app: linkding
spec:
containers:
- name: linkding
image: sissbruecker/linkding:latest
ports:
- containerPort: 9090
env:
- name: LD_SUPERUSER_NAME
value: "admin"
- name: LD_SUPERUSER_PASSWORD
value: "changeme123"
---
apiVersion: v1
kind: Service
metadata:
name: linkding
namespace: linkding
labels:
app: linkding
spec:
selector:
app: linkding
ports:
- port: 9090
targetPort: 9090
​

The Service matches pods with app: linkding label, listens on
port 9090, and forwards to container port 9090.

​

Deploy It

Apply the YAML:

​
kubectl apply -f linkding.yaml
​

​
deployment.apps/linkding created
service/linkding created
​

Watch the pod start:

​
kubectl get pods -w
​

You’ll see it go from Pending → ContainerCreating → Running.

​
NAME READY STATUS RESTARTS AGE
linkding-7d8f9c6b9b-x2kj4 1/1 Running 0 30s
​

Press Ctrl+C to stop watching.

​

Access Linkding

Port-forward to the service:

​
kubectl port-forward service/linkding 8080:9090
​

Open your browser: http://localhost:8080

You should see the Linkding login page.

Log in with username admin and password changeme123.

You’re in.

​

Explore Linkding

Take a few minutes to explore:

* Add a bookmark - Click “Add Bookmark”, paste any URL
* Add some tags - Organize bookmarks by topic
* Search - Use the search bar to find bookmarks

Add a few real bookmarks. Kubernetes documentation.. Your
favorite sites.

​

Checking the Logs

Want to see what Linkding is doing?

​
kubectl logs deployment/linkding
​

You’ll see the Django development server output, incoming
requests, etc.

For live logs:

​
kubectl logs deployment/linkding -f
​

Press Ctrl+C to stop.

​

Inspecting the Pod

See full pod details:

​
kubectl describe pod -l app=linkding
​

The -l app=linkding selects pods by label instead of by name.

You’ll see the container state, environment variables (including
your password, which is why Secrets matter), and events (image
pulled, container started).

​

The Problem We’ll Solve Tomorrow

Try this:

* Stop the port-forward (Ctrl+C)
* Restart the deployment: ​
kubectl rollout restart deployment/linkding
​
* Wait for the new pod: ​
kubectl get pods -w
​
* Port-forward again: ​
kubectl port-forward service/linkding 8080:9090
​
* Go to http://localhost:8080

​

Try to log in with admin/changeme123.

​

Your bookmarks are gone.

Why? Because containers are ephemeral. When a pod restarts, its
filesystem is wiped clean.

SQLite stores data in a file inside the container. That file
disappeared when the container restarted.

This is a critical concept. Containers are stateless by default.

Any data you want to keep must be stored in a Persistent Volume.

Tomorrow, we fix this. You’ll learn about Persistent Volume
Claims and make your bookmarks survive restarts.

For now, appreciate that you have a real application running on
Kubernetes.

Not nginx. A bookmark manager you can actually use.

​

What You Learned Today

Namespaces organize resources in your cluster.

kubectl config set-context changes your default namespace.

Environment variables configure containers.

Multiple resources can live in one YAML file with --- separator.

kubectl logs shows container output.

kubectl describe shows detailed resource information.

Containers are ephemeral. Data doesn’t persist by default.

Tomorrow: Persistent storage. Your bookmarks will survive
anything.

Mischa

​

P.S. Linkding is fun on localhost. But running it with GitOps,
proper secrets management, TLS certificates, and secure internet
access? That’s what HomeLab OS covers inside KubeCraft. You’ll
build a real home lab that impresses interviewers. Not just
tutorial projects. CLICK HERE (
https://ed9688f7.click.convertkit-mail2.com/38u77drlv9hduorlr0pcrh4qgw2nns7h6rqzn/48hvhehmgdpgl0ix/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
) to get access.

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://ed9688f7.unsubscribe.convertkit-mail2.com/38u77drlv9hduorlr0pcrh4qgw2nns7h6rqzn
) | Update your profile (
https://preferences.convertkit-mail2.com/38u77drlv9hduorlr0pcrh4qgw2nns7h6rqzn
)
