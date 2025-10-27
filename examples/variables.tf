variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "my-ecs-cluster"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
