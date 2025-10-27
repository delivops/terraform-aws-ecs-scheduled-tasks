variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "task_name" {
  description = "Name of the scheduled task"
  type        = string
}

variable "schedule_expression" {
  description = "Schedule expression for the task (cron or rate)"
  type        = string
  validation {
    condition = can(regex("^(rate\\(|cron\\()", var.schedule_expression))
    error_message = "Schedule expression must start with either 'rate(' or 'cron('."
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the ECS tasks"
  type        = list(string)
}

variable "ecs_launch_type" {
  description = "Launch type for the ECS task (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
  validation {
    condition     = contains(["FARGATE", "EC2"], var.ecs_launch_type)
    error_message = "Valid values for ecs_launch_type are FARGATE or EC2."
  }
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks (Fargate only)"
  type        = bool
  default     = false
}

variable "initial_role" {
  description = "ARN of the IAM role to use for both task role and execution role"
  type        = string
  default     = ""
}

variable "retry_policy" {
  description = "Retry policy configuration for the EventBridge target"
  type = object({
    maximum_retry_attempts       = optional(number, 2)
    maximum_event_age_in_seconds = optional(number, 3600)
  })
  default = {}
}

variable "event_input" {
  description = "JSON input to pass to the scheduled task"
  type        = string
  default     = ""
  validation {
    condition = var.event_input == "" || can(jsondecode(var.event_input))
    error_message = "event_input must be valid JSON or an empty string."
  }
}

variable "task_count" {
  description = "Number of tasks to run per scheduled execution"
  type        = number
  default     = 1
  validation {
    condition     = var.task_count >= 1 && var.task_count <= 10
    error_message = "task_count must be between 1 and 10."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be one of the valid CloudWatch retention periods."
  }
}

variable "state" {
  description = "State of the EventBridge rule (ENABLED or DISABLED)"
  type        = string
  default     = "ENABLED"
  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.state)
    error_message = "State must be either ENABLED or DISABLED."
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "platform_version" {
  description = "Platform version for Fargate tasks"
  type        = string
  default     = "LATEST"
}

variable "propagate_tags" {
  description = "Propagate tags from the task definition or the service to the tasks"
  type        = string
  default     = "TASK_DEFINITION"
  validation {
    condition     = contains(["TASK_DEFINITION", "NONE"], var.propagate_tags)
    error_message = "propagate_tags must be either TASK_DEFINITION or NONE."
  }
}

variable "placement_constraints" {
  description = "Placement constraints for EC2 launch type"
  type = list(object({
    type       = string
    expression = string
  }))
  default = []
}

variable "enable_ecs_managed_tags" {
  description = "Enable ECS managed tags for the tasks"
  type        = bool
  default     = true
}

variable "group" {
  description = "Group name for the scheduled tasks"
  type        = string
  default     = ""
}

variable "role_arn" {
  description = "ARN of the IAM role that EventBridge assumes to run the task"
  type        = string
  default     = ""
}
