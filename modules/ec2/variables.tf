variable "instance_name" {
  description = "Name tag for instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for instances"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for instances"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}
variable "instance_index_offset" {
  description = "Offset for instance numbering"
  type        = number
  default     = 0
}


variable "environment" {
  description = "Environment name"
  type        = string
}

variable "user_data" {
  description = "User data script for instances"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}