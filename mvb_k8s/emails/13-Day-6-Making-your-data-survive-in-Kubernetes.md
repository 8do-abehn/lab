# Day 6: Making your data survive in Kubernetes

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Sat, 13 Dec 2025 15:28:25 +0000

---

Hey Adam,

Yesterday you saw the problem: restart your pod, lose your data.

Today we fix it with Persistent Volumes.

This is one of the most important concepts in Kubernetes. Every
real application needs storage: databases, file uploads, user
data, configuration.

Understanding how storage works separates beginners from people
who can actually run production workloads.

​

Why Containers Lose Data

When a container starts, it gets a fresh file system from its
image.

Any changes you make (files created, databases populated, logs
written) exist only in that container’s writable layer.

When the container stops, that writable layer is discarded. The
next container starts fresh from the image again.

This is by design. Containers are meant to be disposable.

You should be able to kill a container and start a new one
without worrying about state.

But applications need to store data somewhere. That’s where
volumes come in.

​

Volumes in Kubernetes

A Volume is storage that exists outside the container life cycle.
Data in a volume persists even when containers restart.

Kubernetes has many volume types:

emptyDir provides temporary storage that exists as long as the
pod exists.

hostPath uses a directory on the node (not recommended for
production).

persistentVolumeClaim requests storage from the cluster’s storage
system.

configMap / secret mounts configuration as files.

nfs, awsElasticBlockStore, gcePersistentDisk, azureDisk connect
to cloud/network storage.

​

For our purposes, we’ll use PersistentVolumeClaim (PVC). This is
the standard way to request storage in Kubernetes.

​

The Storage Architecture

Kubernetes storage has three components:

​

PersistentVolume (PV) is the actual storage, a piece of disk
somewhere.

In cloud environments, this might be an AWS EBS volume or Azure
Disk.

Locally, it’s space on your node’s filesystem.

​

PersistentVolumeClaim (PVC) is a request for storage.

You say “I need 1GB of storage with read-write access” and
Kubernetes finds or creates a PV to satisfy that claim.

​

StorageClass defines how storage is provisioned.

Different classes might offer different performance, backup
policies, or underlying storage systems.

​

The flow:

1. You create a PVC requesting storage

2. Kubernetes checks available PVs or dynamically provisions one

3. The PVC binds to a PV

4. Your pod mounts the PVC as a volume

5. Data written to that volume persists across pod restarts

​

Rancher Desktop’s Storage

Rancher Desktop uses K3s, which includes the local-path
StorageClass.

This automatically provisions storage on your node’s filesystem.

​

Check available storage classes:

​
kubectl get storageclass
​

​
NAME PROVISIONER AGE
local-path (default) rancher.io/local-path 3d
​

The (default) means PVCs that don’t specify a storage class will
use this one.

​

Creating a PersistentVolumeClaim

Let’s update our Linkding deployment to use persistent storage.

First, make sure you’re in the linkding namespace:

​
kubectl config set-context --current --namespace=linkding
​

Create a new file called linkding-with-storage.yaml:

yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: linkding-data
namespace: linkding
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 1Gi
---
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
volumeMounts:
- name: linkding-data
mountPath: /etc/linkding/data
volumes:
- name: linkding-data
persistentVolumeClaim:
claimName: linkding-data
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

Let me explain the new parts:

​

PersistentVolumeClaim:

yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: linkding-data
namespace: linkding
spec:
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 1Gi
​

name: linkding-data is what we’ll reference in the deployment.

accessModes: ReadWriteOnce means it can be mounted read-write by
a single node.

storage: 1Gi requests 1 gigabyte of storage.

​

Access modes:

ReadWriteOnce (RWO) allows single node read-write.

ReadOnlyMany (ROX) allows multiple nodes read-only.

ReadWriteMany (RWX) allows multiple nodes read-write (requires
special storage).

​

volumeMounts in the container:

yaml
volumeMounts:
- name: linkding-data
mountPath: /etc/linkding/data
​

This mounts the volume named linkding-data at /etc/linkding/data
inside the container.

Linkding stores its SQLite database in /etc/linkding/data.

By mounting our persistent volume there, the database persists
across restarts.

​

volumes in the pod spec:

yaml
volumes:
- name: linkding-data
persistentVolumeClaim:
claimName: linkding-data
​

This creates a volume from our PVC. The name linkding-data
matches what we referenced in volumeMounts.

​

Deploy the Updated Version

Delete the old deployment and apply the new one:

​
kubectl delete -f linkding.yaml
kubectl apply -f linkding-with-storage.yaml
​

​
persistentvolumeclaim/linkding-data created
deployment.apps/linkding created
service/linkding unchanged
​

Check the PVC:

​
kubectl get pvc
​

​
NAME STATUS VOLUME
CAPACITY ACCESS MODES
linkding-data Bound pvc-a1b2c3d4-e5f6-7890-abcd-ef1234567890
1Gi RWO
​

STATUS: Bound means the PVC has been bound to a PersistentVolume.
Storage is ready.

Check the pod:

​
kubectl get pods
​

Wait for it to be Running.

​

Test the Persistence

Port-forward:

​
kubectl port-forward service/linkding 8080:9090
​

Go to http://localhost:8080 and log in (admin/changeme123).

Add some bookmarks. At least 3-4 that you’d actually want to
keep.

Now the test:

* Stop port-forward (Ctrl+C)
* Restart the deployment: ​
kubectl rollout restart deployment/linkding
​
* Watch the pod restart: ​
kubectl get pods -w
​
* Wait for the new pod to be Running, then Ctrl+C
* Port-forward again: ​
kubectl port-forward service/linkding 8080:9090
​
* Go to http://localhost:8080

​

Log in. Your bookmarks are still there.

​

The pod was destroyed and recreated. A completely new container
started. But your data persisted because it lives in the
PersistentVolume, not the container.

​

Inspecting the Storage

See the PersistentVolume that was created:

​
kubectl get pv
​

​
NAME CAPACITY ACCESS
MODES RECLAIM POLICY STATUS CLAIM
pvc-a1b2c3d4-e5f6-7890-abcd-ef1234567890 1Gi RWO
Delete Bound linkding/linkding-data
​

RECLAIM POLICY: Delete means when the PVC is deleted, the PV is
also deleted.

STATUS: Bound means it’s currently bound to a PVC.

CLAIM: linkding/linkding-data shows the PVC using this PV.

​

Describe the PVC for more details:

​
kubectl describe pvc linkding-data
​

You’ll see the storage class, the bound volume, and mount
information.

​

Looking Inside the Container

Let’s see where the data actually lives:

​
kubectl exec -it deployment/linkding -- /bin/sh
​

You’re now inside the container. Look at the data directory:

​
ls -la /etc/linkding/data
​

​
total 184
drwxr-xr-x 2 root root 4096 Nov 25 12:00 .
drwxr-xr-x 1 root root 4096 Nov 25 11:00 ..
-rw-r--r-- 1 root root 176128 Nov 25 12:05
db.sqlite3
​

There’s the SQLite database. This file lives on the
PersistentVolume.

Exit the container:

​
exit
​

Understanding What Happened

Let’s trace the full flow:

* We created a PVC requesting 1Gi of storage
* The local-path StorageClass provisioned a PersistentVolume on
the node
* The PVC bound to that PV
* Our deployment referenced the PVC in its volumes
* The container mounted the volume at /etc/linkding/data
* Linkding wrote its database to that path
* When the pod restarted, the new container mounted the same
volume
* The database was still there

This is how every stateful application works in Kubernetes:
databases, file servers, message queues. The pattern is always
the same.

​

Storage in Production

In production Kubernetes:

Cloud storage includes AWS EBS, Azure Disk, GCP Persistent Disk.

Network storage includes NFS, Ceph, GlusterFS.

Storage operators include Rook, OpenEBS, Longhorn.

​

You’d have multiple StorageClasses for different needs: fast SSD
storage for databases, cheap HDD storage for backups, replicated
storage for high availability.

The application doesn’t care. It just requests a PVC, and the
cluster provides storage.

​

What You Learned Today

Containers are ephemeral. Data doesn’t persist by default.

PersistentVolume (PV) is actual storage provisioned in the
cluster.

PersistentVolumeClaim (PVC) is a request for storage.

StorageClass defines how storage is provisioned.

volumeMounts defines where to mount storage inside the container.

volumes connects pods to PVCs.

Data survives restarts because it lives outside the container.

​

Your Capstone Project is Complete

You now have a real application running on Kubernetes, organized
in its own namespace, with persistent storage, accessible via
port forward.

This is more than most “Kubernetes tutorials” teach. You’ve
actually built something useful.

Tomorrow, we wrap up and talk about what comes next.

Mischa

​

P.S. You built something real. But it’s still on your laptop with
port-forwarding. Inside KubeCraft, HomeLab OS teaches you to run
this 24/7 on dedicated hardware, expose it to the internet
securely with TLS certificates, set up automatic backups, and
manage it with GitOps. That’s the difference between a tutorial
project and production-ready infrastructure. CLICK HERE (
https://ed9688f7.click.convertkit-mail2.com/d0uqqkp5zncmu4kgk9dtmhzl7d544ilhonw5m/dpheh0he5l4oqpim/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
) if you want those real production skills.

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://ed9688f7.unsubscribe.convertkit-mail2.com/d0uqqkp5zncmu4kgk9dtmhzl7d544ilhonw5m
) | Update your profile (
https://preferences.convertkit-mail2.com/d0uqqkp5zncmu4kgk9dtmhzl7d544ilhonw5m
)
