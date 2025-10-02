terraform {
  backend "s3" {
    # Backend configuration loaded from backend.hcl
    # Run: terraform init -backend-config=backend.hcl
  }
}