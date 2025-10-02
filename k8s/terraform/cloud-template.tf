# Create VM template from existing cloud image
resource "null_resource" "create_cloud_template" {
  provisioner "local-exec" {
    command = <<-EOF
      ssh root@pve001 '
        # Check if template already exists
        if qm status 9000 >/dev/null 2>&1; then
          echo "Template 9000 already exists, removing it first"
          qm destroy 9000
        fi

        # Create VM from cloud image
        qm create 9000 --name "ubuntu-cloud-template" --description "Ubuntu 22.04 cloud-init base template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
        qm importdisk 9000 /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img infra_storage
        qm set 9000 --scsihw virtio-scsi-pci --scsi0 infra_storage:vm-9000-disk-0
        qm set 9000 --boot c --bootdisk scsi0
        qm set 9000 --ide2 infra_storage:cloudinit
        qm set 9000 --serial0 socket --vga serial0
        qm set 9000 --agent enabled=1

        # Convert to template
        qm template 9000

        echo "Ubuntu cloud template created successfully"
      '
    EOF
  }
}