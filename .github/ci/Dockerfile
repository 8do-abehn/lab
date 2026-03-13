FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY ansible/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# GitHub Actions runs as root in containers — ensure git trusts the workspace
RUN git config --system --add safe.directory '*'
