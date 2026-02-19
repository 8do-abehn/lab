# Did you see it happen?

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Tue, 09 Dec 2025 19:32:41 +0000

---

Hey Adam,

​

Quick check-in.

Did you watch Kubernetes self-heal when you deleted that pod?

That moment where you break something and watch the system fix
itself in seconds is when Kubernetes clicks for most people.

It’s not magic. It’s a control loop. Constantly watching.
Constantly reconciling.

This is why companies trust Kubernetes with production workloads.
Not because engineers are watching dashboards 24/7, but because
the system maintains itself.

​

If you got stuck, here’s help:

“kubectl get pods shows no pods”

​

You might have accidentally deleted the deployment. Recreate it:
​
kubectl create deployment my-app --image=nginx --replicas=3
​

“command not found: kubectl”

Rancher Desktop needs to configure your PATH. Open Rancher
Desktop → Preferences → Application → Path → set to Automatic.
Then restart your terminal completely (not just open a new tab).

​

“Pods stuck in Pending”

Your cluster might be resource-constrained. Check node status: ​
kubectl describe node rancher-desktop
​

Look at “Allocatable” vs “Allocated resources.” If you’re near
the limits, go to Rancher Desktop → Preferences → Virtual Machine
and increase memory/CPU.

​

“Pods in CrashLoopBackOff”

The container is crashing. Check logs: ​
kubectl logs
​

If it’s an nginx pod, this shouldn’t happen. Try deleting the
deployment and recreating it.

​

“ImagePullBackOff”

Kubernetes can’t download the container image. This usually
means: 1. Typo in the image name 2. No internet connection 3.
Docker Hub rate limiting (rare for nginx)

Check the image name is exactly nginx (not ngnix or
nginx:lastest).

​

What’s Coming Tomorrow

Your deployment is running. But right now, those pods are
isolated. They have internal IP addresses that change every time
a pod restarts.

How do you actually connect to them? How do you access nginx in
your browser?

Tomorrow: Services - the networking layer that makes everything
work.

Make sure your deployment is still running: ​
kubectl get deployment my-app
​

If you see READY 3/3 (or 2/2, whatever you scaled to), you’re
good.

Talk soon,

Mischa

​

P.S. Most people quit when they hit their first error. They
Google for hours, get frustrated, and give up. Inside KubeCraft,
you get coaching calls where I answer questions live and daily
support from me and my team. You share your screen, I see your
error, we fix it together. No more getting stuck alone. CLICK
HERE (
https://ed9688f7.click.convertkit-mail2.com/wvuddk0xpeh6u54p4x6s7hnqg79xxb8h4qm2e/kkhmh6hnmwlvrzil/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svZTU5ZjZj
) if you want my direct mentorship.

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://ed9688f7.unsubscribe.convertkit-mail2.com/wvuddk0xpeh6u54p4x6s7hnqg79xxb8h4qm2e
) | Update your profile (
https://preferences.convertkit-mail2.com/wvuddk0xpeh6u54p4x6s7hnqg79xxb8h4qm2e
)
