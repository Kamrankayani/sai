# Basic provider configuration


provider "aws" {
  region = var.aws_region
}

# Get the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create VPC using our module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone
  environment       = var.environment

  tags = {
    Project = "k8s-learning"
    Owner   = "devops-team"
  }
}

# Security group for all nodes
resource "aws_security_group" "k8s_nodes" {
  name        = "${var.environment}-k8s-nodes-sg"
  description = "Security group for Kubernetes nodes"
  vpc_id      = module.vpc.vpc_id

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic between nodes
  ingress {
    description = "All traffic between nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-k8s-nodes-sg"
    Environment = var.environment
    Project     = "k8s-learning"
  }
}

# SSH Key
resource "aws_key_pair" "k8s_key" {
  key_name   = "${var.environment}-k8s-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Create EC2 instances using our module
module "control_plane" {
  source = "./modules/ec2"

  instance_name      = "${var.environment}-control-plane"
  instance_type      = var.control_plane_instance_type
  subnet_id          = module.vpc.subnet_id
  security_group_ids = [aws_security_group.k8s_nodes.id]
  key_name           = aws_key_pair.k8s_key.key_name
  ami_id             = data.aws_ami.ubuntu.id
  root_volume_size   = var.control_plane_volume_size
  instance_count     = 1
  environment        = var.environment

  tags = {
    Role = "control-plane"
  }
}

module "workers" {
  source = "./modules/ec2"

  instance_name      = "${var.environment}-worker"
  instance_type      = var.worker_instance_type
  subnet_id          = module.vpc.subnet_id
  security_group_ids = [aws_security_group.k8s_nodes.id]
  key_name           = aws_key_pair.k8s_key.key_name
  ami_id             = data.aws_ami.ubuntu.id
  root_volume_size   = var.worker_volume_size
  instance_count     = var.worker_count
  environment        = var.environment

  tags = {
    Role = "worker"
  }
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    control_plane_ip = module.control_plane.public_ips[0]
    worker_ips       = module.workers.public_ips
    ssh_key_path     = var.ssh_private_key_path
    ansible_user     = "ubuntu"
  })
  filename = "${path.module}/ansible/inventory.yaml"
}