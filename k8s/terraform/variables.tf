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

variable "dev_username" {
  description = "Username for dev server"
  type        = string
  default     = "dev.user"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for dev server access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}