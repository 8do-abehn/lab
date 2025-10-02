variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  # Set via environment variable: export TF_VAR_proxmox_api_token_id="root@pam!your-token"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
  # Set via environment variable: export TF_VAR_proxmox_api_token_secret="your-secret-here"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "terraform-state-homelab-k8s"
}