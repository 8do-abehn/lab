#!/usr/bin/env python3
"""
OpenPLC Configuration Backup Script

Pulls configuration and programs from OpenPLC Runtime via REST API,
stores them in a git repository for version control.

Usage:
    ./openplc-backup.py                    # Backup to ./openplc-backups/
    ./openplc-backup.py --host 10.0.0.1    # Specify host
    ./openplc-backup.py --commit           # Auto-commit changes to git
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import requests


class OpenPLCBackup:
    def __init__(self, host: str, port: int = 8080, user: str = "openplc", password: str = "openplc"):
        self.base_url = f"http://{host}:{port}"
        self.session = requests.Session()
        self.user = user
        self.password = password

    def login(self) -> bool:
        """Authenticate with OpenPLC web interface."""
        try:
            resp = self.session.post(
                f"{self.base_url}/login",
                data={"username": self.user, "password": self.password},
                allow_redirects=False,
            )
            return resp.status_code in [200, 302]
        except requests.RequestException as e:
            print(f"Login failed: {e}")
            return False

    def get_programs(self) -> list:
        """Get list of PLC programs."""
        try:
            resp = self.session.get(f"{self.base_url}/programs")
            if resp.status_code == 200:
                # Parse HTML to extract program list (OpenPLC doesn't have a clean API)
                # This is a simplified extraction
                return self._parse_programs_page(resp.text)
        except requests.RequestException as e:
            print(f"Failed to get programs: {e}")
        return []

    def _parse_programs_page(self, html: str) -> list:
        """Extract program names from the programs page."""
        programs = []
        # Simple extraction - look for .st files in the HTML
        import re
        matches = re.findall(r'href="/program\?name=([^"]+)"', html)
        return list(set(matches))

    def get_program_content(self, name: str) -> str | None:
        """Download a specific program's source code."""
        try:
            resp = self.session.get(f"{self.base_url}/program", params={"name": name})
            if resp.status_code == 200:
                return resp.text
        except requests.RequestException as e:
            print(f"Failed to get program {name}: {e}")
        return None

    def get_settings(self) -> dict:
        """Get OpenPLC settings/configuration."""
        try:
            resp = self.session.get(f"{self.base_url}/settings")
            if resp.status_code == 200:
                return {"raw_html": resp.text, "timestamp": datetime.now().isoformat()}
        except requests.RequestException as e:
            print(f"Failed to get settings: {e}")
        return {}

    def get_hardware_config(self) -> dict:
        """Get hardware layer configuration."""
        try:
            resp = self.session.get(f"{self.base_url}/hardware")
            if resp.status_code == 200:
                return {"raw_html": resp.text, "timestamp": datetime.now().isoformat()}
        except requests.RequestException as e:
            print(f"Failed to get hardware config: {e}")
        return {}


def file_hash(filepath: Path) -> str:
    """Calculate MD5 hash of a file."""
    if not filepath.exists():
        return ""
    return hashlib.md5(filepath.read_bytes()).hexdigest()


def save_backup(backup_dir: Path, plc: OpenPLCBackup) -> dict:
    """Save all OpenPLC configuration to backup directory."""
    backup_dir.mkdir(parents=True, exist_ok=True)
    changes = {"new": [], "modified": [], "programs": []}

    # Backup metadata
    metadata = {
        "backup_time": datetime.now().isoformat(),
        "source": plc.base_url,
    }

    # Get and save programs
    programs_dir = backup_dir / "programs"
    programs_dir.mkdir(exist_ok=True)

    programs = plc.get_programs()
    metadata["programs"] = programs

    for prog in programs:
        content = plc.get_program_content(prog)
        if content:
            prog_file = programs_dir / f"{prog}"
            old_hash = file_hash(prog_file)
            prog_file.write_text(content)
            new_hash = file_hash(prog_file)

            if old_hash == "":
                changes["new"].append(prog)
            elif old_hash != new_hash:
                changes["modified"].append(prog)
            changes["programs"].append(prog)

    # Save settings
    settings = plc.get_settings()
    if settings:
        settings_file = backup_dir / "settings.json"
        old_hash = file_hash(settings_file)
        settings_file.write_text(json.dumps(settings, indent=2))
        if old_hash and old_hash != file_hash(settings_file):
            changes["modified"].append("settings.json")

    # Save hardware config
    hardware = plc.get_hardware_config()
    if hardware:
        hardware_file = backup_dir / "hardware.json"
        old_hash = file_hash(hardware_file)
        hardware_file.write_text(json.dumps(hardware, indent=2))
        if old_hash and old_hash != file_hash(hardware_file):
            changes["modified"].append("hardware.json")

    # Save metadata
    metadata_file = backup_dir / "metadata.json"
    metadata_file.write_text(json.dumps(metadata, indent=2))

    return changes


def git_commit(backup_dir: Path, message: str) -> bool:
    """Commit changes to git repository."""
    try:
        # Check if there are changes
        result = subprocess.run(
            ["git", "status", "--porcelain", str(backup_dir)],
            capture_output=True,
            text=True,
            cwd=backup_dir.parent,
        )
        if not result.stdout.strip():
            print("No changes to commit")
            return False

        # Add and commit
        subprocess.run(["git", "add", str(backup_dir)], check=True, cwd=backup_dir.parent)
        subprocess.run(
            ["git", "commit", "-m", message],
            check=True,
            cwd=backup_dir.parent,
        )
        print(f"Committed: {message}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Git commit failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Backup OpenPLC configuration")
    parser.add_argument("--host", default="10.150.10.139", help="OpenPLC host")
    parser.add_argument("--port", type=int, default=8080, help="OpenPLC port")
    parser.add_argument("--user", default="openplc", help="Username")
    parser.add_argument("--password", default="openplc", help="Password")
    parser.add_argument("--output", default="./openplc-backups", help="Backup directory")
    parser.add_argument("--commit", action="store_true", help="Auto-commit to git")
    args = parser.parse_args()

    backup_dir = Path(args.output)
    plc = OpenPLCBackup(args.host, args.port, args.user, args.password)

    print(f"Connecting to OpenPLC at {plc.base_url}...")
    if not plc.login():
        print("Failed to authenticate with OpenPLC")
        sys.exit(1)

    print("Backing up configuration...")
    changes = save_backup(backup_dir, plc)

    print(f"\nBackup complete: {backup_dir}")
    print(f"  Programs: {len(changes['programs'])}")
    print(f"  New files: {len(changes['new'])}")
    print(f"  Modified: {len(changes['modified'])}")

    if args.commit and (changes["new"] or changes["modified"]):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
        msg = f"OpenPLC backup {timestamp}: {len(changes['new'])} new, {len(changes['modified'])} modified"
        git_commit(backup_dir, msg)


if __name__ == "__main__":
    main()
