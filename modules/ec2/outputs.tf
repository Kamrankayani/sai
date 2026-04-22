output "instance_ids" {
  description = "List of instance IDs"
  value       = aws_instance.this[*].id
}

output "private_ips" {
  description = "List of private IPs"
  value       = aws_instance.this[*].private_ip
}

output "public_ips" {
  description = "List of public IPs"
  value       = aws_eip.this[*].public_ip
}