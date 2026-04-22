# Copy this file to terraform.tfvars and update values as needed

aws_region        = "us-east-1"
environment       = "dev"
availability_zone = "us-east-1a"

# Network configuration
vpc_cidr    = "10.0.0.0/16"
subnet_cidr = "10.0.1.0/24"

# Instance configuration
control_plane_instance_type = "t3.medium"
worker_instance_type        = "t3.medium"
worker_count                = 2

# Storage configuration
control_plane_volume_size = 20
worker_volume_size        = 20

# SSH configuration (update with your key paths)
ssh_public_key_path  = "~/.ssh/id_rsa.pub"
ssh_private_key_path = "~/.ssh/id_rsa"