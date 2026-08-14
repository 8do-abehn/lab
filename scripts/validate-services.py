#!/usr/bin/env python3
import sys
import yaml
from pathlib import Path

p = Path('site/data/services.yml')
if not p.exists():
    print('site/data/services.yml not found', file=sys.stderr)
    sys.exit(1)

try:
    data = yaml.safe_load(p.read_text())
except yaml.YAMLError as exc:
    print(f'Failed to parse YAML: {exc}', file=sys.stderr)
    sys.exit(2)

if data is None:
    print('site/data/services.yml is empty', file=sys.stderr)
    sys.exit(2)

if not isinstance(data, dict):
    print('site/data/services.yml root must be a mapping/object', file=sys.stderr)
    sys.exit(2)

errors = []

def check_url(name, url, ctx):
    if url is None:
        return
    if not isinstance(url, str):
        errors.append(f'{ctx}: {name} is not a string')
        return
    if not (url.startswith('http://') or url.startswith('https://')):
        errors.append(f'{ctx}: {name} has non-http(s) URL: {url}')

# nodes
nodes = data.get('nodes', [])
if not isinstance(nodes, list):
    errors.append('nodes must be a list')
else:
    for i, node in enumerate(nodes):
        ctx = f'nodes[{i}]'
        host = node.get('host')
        if not host:
            errors.append(f'{ctx}: missing host')
        check_url('proxmox_url', node.get('proxmox_url'), ctx)
        check_url('netdata_url', node.get('netdata_url'), ctx)
        containers = node.get('containers', [])
        if not isinstance(containers, list):
            errors.append(f'{ctx}: containers must be a list')
        else:
            for j, c in enumerate(containers):
                cctx = f'{ctx}.containers[{j}]'
                vmid = c.get('vmid')
                if not isinstance(vmid, int):
                    errors.append(f'{cctx}: vmid must be an integer (got {type(vmid).__name__})')
                if 'name' not in c:
                    errors.append(f'{cctx}: missing name')
                check_url('console', c.get('console'), cctx)

# endpoints
endpoints = data.get('endpoints', [])
if not isinstance(endpoints, list):
    errors.append('endpoints must be a list')
else:
    for k, e in enumerate(endpoints):
        ectx = f'endpoints[{k}]'
        check_url('url', e.get('url'), ectx)

if errors:
    print('Validation failed:')
    for e in errors:
        print('- ' + e)
    sys.exit(2)

print('Validation passed')
sys.exit(0)
