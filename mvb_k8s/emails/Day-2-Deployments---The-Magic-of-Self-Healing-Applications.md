# Day 2: Deployments - The Magic of Self-Healing Applications

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Tue, 09 Dec 2025 15:31:25 +0000

---

Hey Adam,

Yesterday you deployed a single pod.

Today you learn why that’s not how anyone runs production
workloads. And what to use instead.

The Problem with Pods

Remember when you deleted your nginx pod? It was gone. Forever.
If that was serving real traffic, your users would see errors.

Pods are ephemeral. They’re designed to be temporary. They can
die for many reasons:

* The node they’re running on crashes
* They run out of memory
* A bug causes them to exit
* You accidentally delete them
* Kubernetes needs to move them during maintenance

If you manually create pods with kubectl run, nobody is watching
them. When they die, they stay dead.

This is where Deployments come in.

​

What is a Deployment?

A Deployment is a higher-level object that manages pods for you.

Instead of saying “create this pod,” you say “I want 3 copies of
this pod running at all times.”

​

Kubernetes then:

- Creates 3 pods

- Monitors their health

- Replaces any that fail

- Maintains your desired count no matter what

​

You declare the desired state. Kubernetes maintains it. This is
called declarative configuration. One of the core principles of
Kubernetes.

​

The Controller Pattern

Behind the scenes, Kubernetes uses something called a controller.
A controller is a loop that constantly:

* Observes the current state
* Compares it to the desired state
* Takes action to reconcile any differences

For Deployments, the Deployment Controller watches your pods. If
you said “3 replicas” and only 2 are running, it creates another
one. If 4 are running somehow, it terminates one.

This happens automatically, 24/7, without any human intervention.

This is how companies run hundreds of services reliably. Not by
having engineers babysit pods, but by declaring what they want
and letting controllers maintain it.

​

Let’s Create a Deployment

​

Run this command:​
kubectl create deployment my-app --image=nginx --replicas=3
​

Let’s break down what this does:

* create deployment creates a Deployment object
* my-app names it “my-app”
* --image=nginx uses the nginx container image
* --replicas=3 runs 3 copies

Check your pods:

​
kubectl get pods
​

​
NAME READY STATUS RESTARTS AGE
my-app-6d9f9c6b9b-7xjdk 1/1 Running 0 10s
my-app-6d9f9c6b9b-bm2qf 1/1 Running 0 10s
my-app-6d9f9c6b9b-tnvrx 1/1 Running 0 10s
​

Three pods, all running. Notice the names have a random suffix.
That’s because these pods are managed by the Deployment, not
created manually.

View the Deployment:

​
kubectl get deployment my-app
​

​
NAME READY UP-TO-DATE AVAILABLE AGE
my-app 3/3 3 3 30s
​

* READY 3/3 means 3 out of 3 desired pods are ready
* UP-TO-DATE means 3 pods match the current configuration
* AVAILABLE means 3 pods are available to serve traffic

​

The Self-Healing Demo

Now let’s break something and watch Kubernetes fix it.

First, open a second terminal window and run:

​
kubectl get pods --watch
​

This will continuously show pod status changes. Keep this
visible.

In your first terminal, copy one of your pod names and delete it:

​
kubectl delete pod my-app-6d9f9c6b9b-7xjdk
​

Watch your second terminal.

You’ll see something like:

​
my-app-6d9f9c6b9b-7xjdk 1/1 Terminating 0 2m
my-app-6d9f9c6b9b-7xjdk 0/1 Terminating 0 2m
my-app-6d9f9c6b9b-r4pmn 0/1 Pending 0 0s
my-app-6d9f9c6b9b-r4pmn 0/1 ContainerCreating 0 0s
my-app-6d9f9c6b9b-r4pmn 1/1 Running 0 2s
​

Within seconds, Kubernetes: 1. Detected a pod was terminated 2.
Noticed only 2 replicas exist but 3 are desired 3. Created a new
pod to replace it 4. Started the container

You’re back to 3 healthy pods. No manual intervention required.

Press Ctrl+C to stop the watch.

​

Scaling Your Deployment

What if you need more capacity? Maybe traffic spiked and 3 pods
aren’t enough.

Scale up to 5:

​
kubectl scale deployment my-app --replicas=5
​

Check pods:

​
kubectl get pods
​

Five pods running. Kubernetes created 2 more.

Scale down to 2:

​
kubectl scale deployment my-app --replicas=2
​

Kubernetes terminates 3 pods, leaving you with 2.

In production, you’d often use a Horizontal Pod Autoscaler that
automatically scales based on CPU or memory usage. But manual
scaling is how you understand the fundamentals.

​

Understanding ReplicaSets

When you create a Deployment, it actually creates another object
called a ReplicaSet.

​
kubectl get replicaset
​

​
NAME DESIRED CURRENT READY AGE
my-app-6d9f9c6b9b 2 2 2 5m
​

The hierarchy is:

​
Deployment
└── ReplicaSet
└── Pods
​

* Deployment manages rollouts and rollbacks
* ReplicaSet ensures the right number of pods exist
* Pods actually run the containers

​

You rarely interact with ReplicaSets directly. Deployments manage
them for you.

But knowing they exist helps you understand what’s happening
under the hood.

​

Deployment Rollouts

Deployments also handle updates gracefully.

Let’s say you want to change the nginx image version:

​
kubectl set image deployment/my-app nginx=nginx:1.25
​

Watch what happens:

​
kubectl rollout status deployment/my-app
​

Kubernetes creates new pods with the new image, waits for them to
be healthy, then terminates the old pods. This is called a
rolling update.

At no point are zero pods running. Traffic keeps flowing during
the update.

You can also check rollout history:

​
kubectl rollout history deployment/my-app
​

And if something goes wrong, roll back:

​
kubectl rollout undo deployment/my-app
​

This is how companies deploy new code dozens of times per day
without downtime.

​

Labels and Selectors

How does the Deployment know which pods belong to it?

Labels.

Every pod created by your Deployment has a label app=my-app. The
Deployment uses a selector to find pods with that label.

See the labels:

​
kubectl get pods --show-labels
​

​
NAME READY STATUS LABELS
my-app-6d9f9c6b9b-bm2qf 1/1 Running
app=my-app,pod-template-hash=6d9f9c6b9b
my-app-6d9f9c6b9b-tnvrx 1/1 Running
app=my-app,pod-template-hash=6d9f9c6b9b
​

Labels are key-value pairs attached to objects. They’re how
Kubernetes organizes and selects things.

You could have multiple deployments in the same namespace like
“frontend”, “backend”, “database”, each with different labels.
Services (which we’ll cover tomorrow) use labels to know which
pods to send traffic to.

​

Clean Up (Don’t Do This Yet)

We’ll use this deployment tomorrow. But when you eventually want
to delete it:

​
kubectl delete deployment my-app
​

This deletes the Deployment, which deletes the ReplicaSet, which
deletes all the pods. Clean.

​

What You Learned Today

* Pods are ephemeral and can die at any time. They won’t come
back on their own
* Deployments manage pods and ensure your desired replica count
is maintained
* Self-healing means Kubernetes automatically replaces failed
pods
* Scaling lets you change replica count with a single command
* ReplicaSets are the object between Deployments and Pods
* Rolling updates deploy new versions without downtime
* Labels and selectors are how Kubernetes organizes and finds
objects

​

Tomorrow, we tackle networking. Your pods are running, but how do
you actually connect to them? That’s where Services come in.

Keep the deployment running. We’ll need it.

Mischa

​

P.S. Self-healing is just the beginning. In KubeCraft, you’ll
learn horizontal pod autoscaling, pod disruption budgets, rolling
update strategies, and GitOps workflows that deploy automatically
when you push to Git. This is what separates tutorial-watchers
from engineers who get hired. CLICK HERE (
https://ed9688f7.click.convertkit-mail2.com/d0uqqkp5zncmu4kgke3hmhzl7d544ilhonw5m/n2hohvhvrq5zomt6/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
) to get access.

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://ed9688f7.unsubscribe.convertkit-mail2.com/d0uqqkp5zncmu4kgke3hmhzl7d544ilhonw5m
) | Update your profile (
https://preferences.convertkit-mail2.com/d0uqqkp5zncmu4kgke3hmhzl7d544ilhonw5m
)
