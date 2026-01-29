# Learning K8s with MVB (KubeCraft)

This folder contains tools and resources for tracking my progress through the [KubeCraft 7-Day Kubernetes Quickstart Course](https://kubecraft.dev) by Mischa van den Burg.

## Course Overview

A 6-day hands-on course covering:

| Day | Topic | Key Concepts |
|-----|-------|--------------|
| 1 | Your Kubernetes Journey Starts Now | K8s architecture, containers, clusters |
| 2 | Deployments | Self-healing, scaling, ReplicaSets, rolling updates |
| 3 | Networking | Services, ClusterIP, NodePort, port-forwarding, DNS |
| 4 | The Real Way to Do K8s | YAML manifests, declarative config, kubectl apply |
| 5 | Deploy Something Real | Namespaces, Linkding deployment, environment variables |
| 6 | Data Persistence | PersistentVolumes, PVCs, StorageClass |

## Files in this Directory

```
mvb_k8s/
├── emails/                    # Original course emails (.eml files)
├── k8s_course.py              # Python class for parsing course data
├── create_github_issues.py    # Script to create GitHub issues from tasks
├── email_summary.json         # Parsed email data (auto-generated)
├── github_issues.json         # GitHub issues ready to create (auto-generated)
└── README.md                  # This file
```

## Quick Start

### 1. View Course Summary

```bash
python k8s_course.py
```

This will show:
- Course statistics (lessons, commands, concepts)
- List of all lessons
- Generate `github_issues.json` for tracking progress

### 2. Create GitHub Issues for Progress Tracking

If you're authenticated with the GitHub CLI, use your existing token:

```bash
export GITHUB_TOKEN=$(gh auth token)

# Dry run (see what would be created)
python create_github_issues.py

# Actually create the issues
python create_github_issues.py --create

# Create only Day 2 issues
python create_github_issues.py --create --day 2
```

## Using the Python Classes

The `k8s_course.py` module provides classes you can use in your own scripts:

```python
from k8s_course import K8sCourse, Lesson, LearningTask

# Load the course
course = K8sCourse()
course.load_from_json("email_summary.json")

# Get a specific lesson
day3 = course.get_lesson(3)
print(f"Day 3: {day3.subject}")
print(f"Commands to practice: {len(day3.kubectl_commands)}")

# Get all tasks
tasks = course.get_all_tasks()
for task in tasks:
    print(f"- {task.title}")

# Export for GitHub
course.export_github_issues_json("my_issues.json")
```

## Learning Notes

This project was created as a Python learning exercise. Key concepts used:

- **Dataclasses**: Clean way to define data-holding classes
- **Type hints**: `List[str]`, `Optional[int]` for better code clarity
- **JSON parsing**: Reading and writing structured data
- **HTTP requests**: Using the GitHub API
- **Command-line arguments**: `argparse` for flexible scripts

## Prerequisites

- Python 3.8+
- `requests` library for GitHub API

```bash
pip install requests --break-system-packages
```

## Related Resources

- [KubeCraft](https://kubecraft.dev) - The course provider
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
