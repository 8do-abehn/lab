# Day 4: The real way to do Kubernetes

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Thu, 11 Dec 2025 15:31:55 +0000

---

Hey Adam,

​

So far, you’ve been running kubectl commands like:

​
kubectl create deployment my-app --image=nginx --replicas=3
kubectl expose deployment my-app --port=80
​

This works for learning. But it’s not how anyone runs production
Kubernetes.

The problem with commands:

* No record of what you did
* Hard to reproduce
* Can’t review changes before applying
* No version control
* “What was that flag again?”

The solution: YAML manifests.

​

Infrastructure as Code

In Kubernetes, everything is defined in YAML files. Your
deployments, services, storage, configuration. All written as
code.

This is called declarative configuration. Instead of running
commands (imperative: “do this”), you write files that describe
the desired state (declarative: “this is what I want”).

You commit these files to Git. Now your infrastructure is:

Version controlled. See who changed what and when.

Reviewable. Pull requests for infrastructure changes.

Reproducible. Anyone can deploy the same thing.

Documented. The YAML is the documentation.

​

This is the foundation of GitOps, a practice where Git is the
source of truth for your infrastructure. Push to Git, and your
cluster updates automatically.

​

Anatomy of a Kubernetes YAML File

Let’s look at a Deployment manifest:

yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: my-app
labels:
app: my-app
spec:
replicas: 3
selector:
matchLabels:
app: my-app
template:
metadata:
labels:
app: my-app
spec:
containers:
- name: nginx
image: nginx:1.25
ports:
- containerPort: 80
​

Let’s break down every section:

apiVersion: apps/v1

Kubernetes has multiple API versions. Different resource types
live in different API groups:

v1 contains core resources (Pods, Services, ConfigMaps).

apps/v1 contains application resources (Deployments,
StatefulSets).

networking.k8s.io/v1 contains networking (Ingress,
NetworkPolicy).

​

For Deployments, it’s apps/v1.

​

kind: Deployment

What type of resource you’re creating.

Kubernetes has dozens of resource types: Deployment, Service,
Pod, ConfigMap, Secret, PersistentVolumeClaim, and more.

metadata:

Information about the resource:

name is the resource name (must be unique in the namespace).

labels are key-value pairs for organization and selection.

namespace specifies which namespace (default if not specified).

annotations are additional metadata (not used for selection).

spec:

The specification, meaning what you actually want. This varies by
resource type.

For a Deployment spec:

replicas: 3

How many pods to run.

selector:

How the Deployment finds its pods. Must match the labels in the
pod template.

yaml
selector:
matchLabels:
app: my-app
​

This says “manage pods that have the label app=my-app.”

template:

The pod template - what each pod looks like. This has its own
metadata and spec:

yaml
template:
metadata:
labels:
app: my-app # Must match selector
spec:
containers:
- name: nginx
image: nginx:1.25
ports:
- containerPort: 80
​

The pod template’s labels MUST match the selector. This is how
the Deployment knows which pods belong to it.

containers:

A list of containers to run in each pod. Each container has:

name is the container name.

image is the container image (from Docker Hub or other registry).

ports defines the ports the container listens on. env sets
environment variables (we’ll use this later).

resources sets CPU/memory requests and limits.

volumeMounts defines where to mount storage.

​

Create Your First YAML File

Let’s do this for real. First, clean up anything running:

​
kubectl delete deployment my-app
kubectl delete service my-app
​

Create a file called deployment.yaml:

yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: my-app
labels:
app: my-app
spec:
replicas: 3
selector:
matchLabels:
app: my-app
template:
metadata:
labels:
app: my-app
spec:
containers:
- name: nginx
image: nginx:1.25
ports:
- containerPort: 80
​

Save it. Now apply it:

​
kubectl apply -f deployment.yaml
​

​
deployment.apps/my-app created
​

Check your pods:

​
kubectl get pods
​

Three pods running - created from your YAML file.

​

The Power of apply

kubectl apply is idempotent. Run it again:

​
kubectl apply -f deployment.yaml
​

​
deployment.apps/my-app unchanged
​

Nothing changed because the current state already matches the
desired state.

Now edit the file. Change replicas: 3 to replicas: 5.

​

Apply again:

​
kubectl apply -f deployment.yaml
​

​
deployment.apps/my-app configured
​

“Configured” means Kubernetes detected the difference and updated
the deployment. Check pods:

​
kubectl get pods
​

Five pods now. You didn’t run a “scale” command. You changed the
file and applied it. This is declarative configuration.

​

Multiple Resources in One File

You can define multiple resources in a single YAML file using ---
as a separator.

Create app.yaml:

yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: my-app
labels:
app: my-app
spec:
replicas: 2
selector:
matchLabels:
app: my-app
template:
metadata:
labels:
app: my-app
spec:
containers:
- name: nginx
image: nginx:1.25
ports:
- containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
name: my-app
labels:
app: my-app
spec:
selector:
app: my-app
ports:
- port: 80
targetPort: 80
​

Delete the old deployment first:

​
kubectl delete -f deployment.yaml
​

Apply the new file:

​
kubectl apply -f app.yaml
​

​
deployment.apps/my-app created
service/my-app created
​

Both resources created with one command. Check them:

​
kubectl get deployment,service
​

​

Generating YAML from Commands

​

Don’t want to write YAML from scratch? Use the dry run flag:

​
kubectl create deployment test --image=nginx --replicas=2
--dry-run=client -o yaml
​

This outputs the YAML without creating anything. You can redirect
it to a file:

​
kubectl create deployment test --image=nginx --replicas=2
--dry-run=client -o yaml > test.yaml
​

Same for services:

​
kubectl create service clusterip test --tcp=80:80
--dry-run=client -o yaml
​

This is a huge time saver, especially when you’re learning.
Generate the YAML, then customize it.

Pro tip for exams: The CKA and CKAD exams are timed. Using
--dry-run=client -o yaml to generate YAML quickly is essential.

​

Viewing Existing Resources as YAML

Want to see how an existing resource is defined?

​
kubectl get deployment my-app -o yaml
​

This dumps the full YAML, including defaults Kubernetes added.
It’s verbose, but useful for understanding what’s possible.

​

Deleting with YAML

Just like apply, you can delete using the file:

​
kubectl delete -f app.yaml
​

This removes everything defined in the file.

​

What You Learned Today

YAML manifests define resources declaratively.

apiVersion, kind, metadata, spec form the structure of every
Kubernetes resource.

kubectl apply creates or updates resources to match the file.

Multiple resources can live in one file separated by ---.

–dry-run=client -o yaml generates YAML from commands.

Infrastructure as Code means your cluster state is version
controlled.

​

Tomorrow we continue with the next lesson.

Mischa

​

P.S. YAML is just the beginning. Real Kubernetes engineers use
Helm charts for templating, Kustomize for environment overlays,
and GitOps tools like ArgoCD that automatically sync your cluster
to Git. Inside KubeCraft, you learn all of it - the full
production workflow, not just basics. CLICK HERE (
https://ed9688f7.click.convertkit-mail2.com/n4uzz385kgbqu8gpg2lf6h68xz5ggflhg7pqx/reh8hohmxr7nllc2/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
) to apply.

​

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://ed9688f7.unsubscribe.convertkit-mail2.com/n4uzz385kgbqu8gpg2lf6h68xz5ggflhg7pqx
) | Update your profile (
https://preferences.convertkit-mail2.com/n4uzz385kgbqu8gpg2lf6h68xz5ggflhg7pqx
)
