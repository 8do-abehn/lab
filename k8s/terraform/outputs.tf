output "template_status" {
  description = "Status of the Ubuntu cloud template creation"
  value       = "Ubuntu cloud template created with VM ID 9000"
  depends_on  = [null_resource.create_cloud_template]
}

output "template_name" {
  description = "Name of the created template"
  value       = "ubuntu-cloud-template"
}

output "template_id" {
  description = "VM ID of the template"
  value       = "9000"
}