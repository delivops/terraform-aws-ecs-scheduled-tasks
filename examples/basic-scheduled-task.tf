################################################################################
# Basic Scheduled Task Example
# This example shows simple scheduled tasks using EventBridge Rules
################################################################################

module "daily_cleanup_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "daily-cleanup"
  schedule_expression = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
  description         = "Daily cleanup task"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Use default launch type (FARGATE)
  # Task definition will be overridden externally

  tags = {
    Environment = "production"
    Purpose     = "cleanup"
  }
}

################################################################################
# Hourly Task
################################################################################

module "hourly_processor" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "hourly-data-processor"
  schedule_expression = "rate(1 hour)"
  description         = "Hourly data processing"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  task_count         = 2 # Run 2 instances
  log_retention_days = 14

  tags = {
    Environment = "production"
    Team        = "data"
  }
}

################################################################################
# Task with Event Input
################################################################################

module "etl_task_with_input" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "etl-pipeline"
  schedule_expression = "cron(0 6 * * MON-FRI *)" # Weekdays at 6 AM
  description         = "ETL pipeline for data sync"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Pass configuration as JSON to the task
  event_input = jsonencode({
    operation = "full-sync"
    source = {
      type   = "s3"
      bucket = "raw-data-bucket"
      prefix = "incoming/"
    }
    destination = {
      type     = "database"
      endpoint = "analytics.cluster.amazonaws.com"
    }
  })

  retry_policy = {
    maximum_retry_attempts = 3
  }

  tags = {
    Environment = "production"
    Pipeline    = "etl"
  }
}

################################################################################
# High Frequency Monitor
################################################################################

module "high_frequency_monitor" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "health-monitor"
  schedule_expression = "rate(5 minutes)"
  description         = "Health monitoring every 5 minutes"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  task_count = 1

  retry_policy = {
    maximum_retry_attempts = 5
  }

  log_retention_days = 3

  tags = {
    Environment = "production"
    Critical    = "true"
  }
}

# Expected resources created:
# - 1 ECS Task Definition per module
# - 1 EventBridge Schedule per module
# - 1 CloudWatch Log Group per module
# - 1 IAM Role + Policy (shared, if not provided)
