output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = module.vpc.subnet_id
}

output "control_plane_public_ip" {
  description = "Public IP of control plane node"
  value       = module.control_plane.public_ips[0]
}

output "control_plane_private_ip" {
  description = "Private IP of control plane node"
  value       = module.control_plane.private_ips[0]
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = module.workers.public_ips
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = module.workers.private_ips
}