variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for subnet"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}