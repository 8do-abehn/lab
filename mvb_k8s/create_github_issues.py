#!/usr/bin/env python3
"""
Create GitHub Issues from Course Tasks

This script reads the github_issues.json file and creates issues
in your GitHub repository using the GitHub API.

PREREQUISITES:
1. Create a GitHub Personal Access Token (PAT):
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Select scopes: 'repo' (full control of private repositories)
   - Copy the token and save it securely

2. Set your token as an environment variable:
   export GITHUB_TOKEN="your_token_here"

   Or create a .env file (don't commit this to git!):
   GITHUB_TOKEN=your_token_here

USAGE:
   python create_github_issues.py                 # Dry run (shows what would be created)
   python create_github_issues.py --create        # Actually create the issues
   python create_github_issues.py --create --day 2  # Only create Day 2 issues

LEARNING NOTES:
- This uses the 'requests' library for HTTP requests
- The GitHub API uses REST (like most web APIs)
- Authentication is done via a token in the Authorization header
"""

import os
import sys
import json
import time
import argparse
from typing import List, Dict, Optional

# We use the requests library for HTTP calls
# If not installed: pip install requests --break-system-packages
try:
    import requests
except ImportError:
    print("Error: 'requests' library not installed.")
    print("Install it with: pip install requests --break-system-packages")
    sys.exit(1)


# Configuration
REPO_OWNER = "8do-abehn"
REPO_NAME = "lab"
GITHUB_API_URL = "https://api.github.com"


def get_github_token() -> Optional[str]:
    """
    Get the GitHub token from environment variable or .env file.

    Returns:
        The token string, or None if not found
    """
    # First check environment variable
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        return token

    # Try to read from .env file
    env_file = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_file):
        with open(env_file, 'r') as f:
            for line in f:
                if line.startswith("GITHUB_TOKEN="):
                    return line.strip().split("=", 1)[1]

    return None


def load_issues(json_path: str, day_filter: Optional[int] = None) -> List[Dict]:
    """
    Load issues from the JSON file.

    Args:
        json_path: Path to github_issues.json
        day_filter: If set, only return issues for this day

    Returns:
        List of issue dictionaries
    """
    with open(json_path, 'r') as f:
        issues = json.load(f)

    if day_filter is not None:
        # Filter to only issues with the matching day label
        day_label = f"day-{day_filter}"
        issues = [i for i in issues if day_label in i.get('labels', [])]

    return issues


def ensure_labels_exist(token: str, labels: List[str]) -> None:
    """
    Create labels in the repository if they don't exist.

    Args:
        token: GitHub API token
        labels: List of label names to ensure exist
    """
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    # Label colors by type
    label_colors = {
        "kubernetes": "326CE5",  # K8s blue
        "learning": "0E8A16",    # Green
    }
    # Day labels get a gradient of blues
    day_colors = {
        "day-1": "E0F7FA",
        "day-2": "B2EBF2",
        "day-3": "80DEEA",
        "day-4": "4DD0E1",
        "day-5": "26C6DA",
        "day-6": "00BCD4",
    }

    for label in labels:
        # Determine color
        if label in label_colors:
            color = label_colors[label]
        elif label in day_colors:
            color = day_colors[label]
        else:
            color = "CCCCCC"  # Default gray

        url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/labels"
        data = {
            "name": label,
            "color": color
        }

        response = requests.post(url, headers=headers, json=data)

        if response.status_code == 201:
            print(f"  Created label: {label}")
        elif response.status_code == 422:
            # Label already exists, that's fine
            pass
        else:
            print(f"  Warning: Could not create label '{label}': {response.status_code}")


def create_issue(token: str, issue: Dict, dry_run: bool = True) -> bool:
    """
    Create a single issue in GitHub.

    Args:
        token: GitHub API token
        issue: Issue dictionary with title, body, labels
        dry_run: If True, just print what would happen

    Returns:
        True if successful (or dry run), False otherwise
    """
    if dry_run:
        print(f"\n[DRY RUN] Would create issue:")
        print(f"  Title: {issue['title']}")
        print(f"  Labels: {issue['labels']}")
        print(f"  Body: {issue['body'][:100]}...")
        return True

    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/issues"

    data = {
        "title": issue["title"],
        "body": issue["body"],
        "labels": issue["labels"]
    }

    response = requests.post(url, headers=headers, json=data)

    if response.status_code == 201:
        result = response.json()
        print(f"  Created: #{result['number']} - {issue['title']}")
        return True
    else:
        print(f"  Error creating issue: {response.status_code}")
        print(f"  Response: {response.text}")
        return False


def check_existing_issues(token: str) -> List[str]:
    """
    Get titles of existing open issues to avoid duplicates.

    Args:
        token: GitHub API token

    Returns:
        List of existing issue titles
    """
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/issues"
    params = {"state": "all", "per_page": 100}

    response = requests.get(url, headers=headers, params=params)

    if response.status_code == 200:
        issues = response.json()
        return [i["title"] for i in issues]

    return []


def main():
    """Main function - parse arguments and create issues."""
    parser = argparse.ArgumentParser(
        description="Create GitHub issues from course tasks"
    )
    parser.add_argument(
        "--create",
        action="store_true",
        help="Actually create the issues (default is dry run)"
    )
    parser.add_argument(
        "--day",
        type=int,
        help="Only create issues for a specific day (1-6)"
    )
    parser.add_argument(
        "--json",
        default="github_issues.json",
        help="Path to the issues JSON file"
    )
    parser.add_argument(
        "--skip-duplicates",
        action="store_true",
        default=True,
        help="Skip issues that already exist (default: True)"
    )

    args = parser.parse_args()
    dry_run = not args.create

    # Get token
    token = get_github_token()
    if not token:
        print("Error: GitHub token not found!")
        print("\nTo set up authentication:")
        print("1. Go to https://github.com/settings/tokens")
        print("2. Generate a new token with 'repo' scope")
        print("3. Run: export GITHUB_TOKEN='your_token_here'")
        print("\nOr create a .env file in this directory with:")
        print("GITHUB_TOKEN=your_token_here")
        sys.exit(1)

    # Find the JSON file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, args.json)

    if not os.path.exists(json_path):
        print(f"Error: Could not find {json_path}")
        sys.exit(1)

    # Load issues
    issues = load_issues(json_path, args.day)

    if not issues:
        print("No issues to create.")
        sys.exit(0)

    print(f"\n{'='*60}")
    print(f"  GitHub Issue Creator for K8s Course")
    print(f"  Repository: {REPO_OWNER}/{REPO_NAME}")
    print(f"  Mode: {'CREATE' if not dry_run else 'DRY RUN'}")
    if args.day:
        print(f"  Filter: Day {args.day} only")
    print(f"  Total issues: {len(issues)}")
    print(f"{'='*60}")

    # Check for existing issues to avoid duplicates
    existing_titles = []
    if args.skip_duplicates and not dry_run:
        print("\nChecking for existing issues...")
        existing_titles = check_existing_issues(token)
        print(f"  Found {len(existing_titles)} existing issues")

    # Collect all unique labels
    all_labels = set()
    for issue in issues:
        all_labels.update(issue.get('labels', []))

    # Ensure labels exist (skip in dry run)
    if not dry_run:
        print("\nEnsuring labels exist...")
        ensure_labels_exist(token, list(all_labels))

    # Create issues
    print(f"\n{'Creating' if not dry_run else 'Would create'} issues:")
    created = 0
    skipped = 0

    for issue in issues:
        # Skip if already exists
        if issue["title"] in existing_titles:
            print(f"  Skipping (exists): {issue['title']}")
            skipped += 1
            continue

        if create_issue(token, issue, dry_run):
            created += 1
            # Be nice to the API - add a small delay between requests
            if not dry_run:
                time.sleep(0.5)

    # Summary
    print(f"\n{'='*60}")
    print(f"  Summary")
    print(f"{'='*60}")
    if dry_run:
        print(f"  Would create: {created} issues")
        print(f"\n  Run with --create to actually create the issues")
    else:
        print(f"  Created: {created} issues")
        print(f"  Skipped: {skipped} issues (already existed)")
        print(f"\n  View issues at: https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")


if __name__ == "__main__":
    main()
