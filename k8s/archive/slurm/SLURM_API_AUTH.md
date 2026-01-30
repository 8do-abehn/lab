# Slurm REST API Authentication

## Problem

When accessing the Slurm REST API, you'll encounter an authentication error:

```bash
curl -X GET http://localhost:6820/slurm/v0.0.40/jobs
# Returns: Authentication failure
```

The Slurm REST API requires JWT (JSON Web Token) authentication for all requests.

---

## Solution 1: Use Login Node (Recommended for Interactive Work)

The easiest way to interact with Slurm is through the login node, which has authenticated access built-in.

### Access the login node

```bash
kubectl -n slurm exec -it $(kubectl -n slurm get pod -l app.kubernetes.io/component=login -o name | head -1) -- bash
```

### Use standard Slurm commands

Once inside the login node, you have full authenticated access:

```bash
# View cluster status
sinfo

# View job queue
squeue

# Run a simple test job
srun hostname

# Submit a batch job
cat > test-job.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --output=test-%j.out
#SBATCH --ntasks=1
#SBATCH --time=00:01:00

echo "Running on: $(hostname)"
date
sleep 5
echo "Job complete!"
EOF

sbatch test-job.sh

# Check job status
squeue

# View output
cat test-*.out
```

**Pros:**
- ✅ No authentication setup needed
- ✅ Full Slurm command access
- ✅ Interactive shell environment
- ✅ Perfect for learning and testing

**Cons:**
- ❌ Not suitable for programmatic access
- ❌ Requires kubectl access

---

## Solution 2: JWT Token Authentication (For Programmatic Access)

For programmatic access via the REST API, you need to generate a JWT token.

### Step 1: Port-forward the REST API

```bash
kubectl -n slurm port-forward svc/slurm-restapi 6820:6820
```

Keep this running in a terminal.

### Step 2: Generate JWT Token

In a new terminal, exec into the Slurm controller:

```bash
kubectl -n slurm exec -it $(kubectl -n slurm get pod -l app.kubernetes.io/component=controller -o name | head -1) -- bash
```

Inside the controller pod, generate a token:

```bash
# Generate token for root user (adjust username as needed)
scontrol token username=root

# Or generate for slurm user
scontrol token username=slurm
```

**Output will look like:**
```
SLURM_JWT=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3MDk1ODQwMDAsImlhdCI6MTcwOTU4MDQwMCwic3VuIjoicm9vdCJ9.xxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Copy the entire token (the part after `SLURM_JWT=`).

### Step 3: Use the Token

Export the token in your terminal:

```bash
export SLURM_JWT="eyJ0eXAiOiJKV1QiLCJhbGc..."
```

### Step 4: Make Authenticated API Requests

Use the token in your API calls with headers:

```bash
# List jobs
curl -H "X-SLURM-USER-NAME:root" \
     -H "X-SLURM-USER-TOKEN:$SLURM_JWT" \
     http://localhost:6820/slurm/v0.0.40/jobs

# Get cluster info
curl -H "X-SLURM-USER-NAME:root" \
     -H "X-SLURM-USER-TOKEN:$SLURM_JWT" \
     http://localhost:6820/slurm/v0.0.40/diag

# List nodes
curl -H "X-SLURM-USER-NAME:root" \
     -H "X-SLURM-USER-TOKEN:$SLURM_JWT" \
     http://localhost:6820/slurm/v0.0.40/nodes

# List partitions
curl -H "X-SLURM-USER-NAME:root" \
     -H "X-SLURM-USER-TOKEN:$SLURM_JWT" \
     http://localhost:6820/slurm/v0.0.40/partitions
```

### Pretty Print with jq

For readable JSON output:

```bash
curl -s -H "X-SLURM-USER-NAME:root" \
     -H "X-SLURM-USER-TOKEN:$SLURM_JWT" \
     http://localhost:6820/slurm/v0.0.40/jobs | jq .
```

### Submit a Job via REST API

```bash
curl -X POST \
     -H "X-SLURM-USER-NAME:root" \
     -H "X-SLURM-USER-TOKEN:$SLURM_JWT" \
     -H "Content-Type: application/json" \
     -d '{
       "job": {
         "name": "api-test-job",
         "script": "#!/bin/bash\necho \"Hello from REST API!\"\nhostname\ndate\nsleep 10"
       }
     }' \
     http://localhost:6820/slurm/v0.0.40/job/submit
```

**Pros:**
- ✅ Programmatic access
- ✅ Can be scripted
- ✅ Remote access via API

**Cons:**
- ❌ Requires token generation
- ❌ Tokens expire (default 1 hour)
- ❌ More setup overhead

---

## Token Expiration

JWT tokens expire after a certain period (typically 1 hour by default).

**When token expires:**
- API calls will return authentication errors again
- Generate a new token using `scontrol token`

**To check token expiration:**

Decode the JWT token to see expiration time:

```bash
# Install jq if not available
# macOS: brew install jq

# Decode token (base64 decode the payload)
echo "$SLURM_JWT" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .

# Look for the "exp" field (Unix timestamp)
```

---

## Alternative: Create Persistent Token Script

Create a helper script to regenerate tokens easily:

```bash
# save as get-slurm-token.sh
#!/bin/bash

echo "Generating Slurm JWT token..."

TOKEN=$(kubectl -n slurm exec -i $(kubectl -n slurm get pod -l app.kubernetes.io/component=controller -o name | head -1) -- scontrol token username=root 2>/dev/null | grep SLURM_JWT | cut -d'=' -f2)

if [ -n "$TOKEN" ]; then
    echo "Token generated successfully!"
    echo ""
    echo "Export this in your terminal:"
    echo "export SLURM_JWT=\"$TOKEN\""
    echo ""
    echo "Or copy this complete curl command:"
    echo "curl -H \"X-SLURM-USER-NAME:root\" -H \"X-SLURM-USER-TOKEN:$TOKEN\" http://localhost:6820/slurm/v0.0.40/jobs"
else
    echo "Failed to generate token. Is the Slurm controller running?"
fi
```

Make it executable:

```bash
chmod +x get-slurm-token.sh
```

Use it:

```bash
./get-slurm-token.sh
# Copy the export command it outputs
```

---

## REST API Endpoints Reference

### Common Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/slurm/v0.0.40/ping` | GET | Health check (no auth needed) |
| `/slurm/v0.0.40/diag` | GET | Cluster diagnostics |
| `/slurm/v0.0.40/jobs` | GET | List all jobs |
| `/slurm/v0.0.40/job/{job_id}` | GET | Get specific job details |
| `/slurm/v0.0.40/job/submit` | POST | Submit new job |
| `/slurm/v0.0.40/nodes` | GET | List compute nodes |
| `/slurm/v0.0.40/partitions` | GET | List partitions |
| `/openapi/v3` | GET | OpenAPI specification |

### Authentication Headers Required

All endpoints (except `/ping` and `/openapi`) require:

```
X-SLURM-USER-NAME: <username>
X-SLURM-USER-TOKEN: <jwt-token>
```

---

## Troubleshooting

### "Authentication failure"
- **Cause:** Missing or invalid JWT token
- **Fix:** Generate new token with `scontrol token`

### "Token expired"
- **Cause:** JWT token has passed expiration time
- **Fix:** Generate new token

### "Invalid token format"
- **Cause:** Token not properly formatted in header
- **Fix:** Ensure token is passed exactly as generated, no extra spaces

### "User not found"
- **Cause:** Username in `X-SLURM-USER-NAME` doesn't match token user
- **Fix:** Use same username as when generating token

### REST API pod not responding
```bash
# Check if REST API pod is running
kubectl -n slurm get pods -l app.kubernetes.io/component=restapi

# Check logs
kubectl -n slurm logs -l app.kubernetes.io/component=restapi
```

---

## Recommendation

**For learning and testing:** Use the **login node** (Solution 1)
- Faster to get started
- Full Slurm command experience
- No token management

**For automation and integration:** Use **JWT tokens** (Solution 2)
- Can integrate with scripts and applications
- Remote access capability
- Production-ready approach

---

## Resources

- [Slurm REST API Documentation](https://slurm.schedmd.com/rest_api.html)
- [Slinky Project Documentation](https://slinky.schedmd.com/)
- [JWT Token Format](https://jwt.io/)

---

*Last updated: October 21, 2025*
*Tested on: Slinky v0.4.1 with Slurm REST API v0.0.40*
