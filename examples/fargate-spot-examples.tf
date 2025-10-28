################################################################################
# Fargate Spot and Capacity Provider Examples
# This example demonstrates different ways to use Fargate Spot for cost savings
################################################################################

################################################################################
# Example 1: 100% Fargate Spot (Maximum Cost Savings)
# Best for: Fault-tolerant, interruptible workloads
# Cost savings: Up to 70% compared to regular Fargate
################################################################################

module "fargate_spot_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "data-sync-spot"
  schedule_expression = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
  description         = "Daily data sync on Fargate Spot"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # 100% Fargate Spot configuration
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 0
    }
  ]

  assign_public_ip   = false
  log_retention_days = 7

  tags = {
    Environment = "production"
    CostCenter  = "engineering"
    Type        = "spot"
  }
}

################################################################################
# Example 2: Mixed Strategy - 80% Spot, 20% Regular Fargate
# Best for: Production workloads that need high availability but want cost savings
# Balances cost (80% savings) with reliability (20% guaranteed capacity)
################################################################################

module "mixed_strategy_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "report-generator-mixed"
  schedule_expression = "cron(0 8 * * MON-FRI *)" # Weekdays at 8 AM
  description         = "Report generator with mixed capacity strategy"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Mixed capacity provider strategy
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 80
      base              = 0
    },
    {
      capacity_provider = "FARGATE"
      weight            = 20
      base              = 0
    }
  ]

  task_count = 3 # Run 3 instances

  # Enhanced retry policy for spot interruptions
  retry_policy = {
    maximum_retry_attempts = 3
  }

  assign_public_ip   = false
  log_retention_days = 14

  tags = {
    Environment = "production"
    Team        = "analytics"
    Type        = "mixed-spot"
  }
}

################################################################################
# Example 3: Spot with Base Capacity
# First N tasks on regular Fargate, rest on Spot
# Best for: Critical tasks that need guaranteed minimum capacity
################################################################################

module "spot_with_base_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "critical-processor"
  schedule_expression = "rate(30 minutes)"
  description         = "Critical processor with guaranteed base capacity"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Ensure at least 1 task always runs on regular Fargate
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight            = 0
      base              = 1 # First task guaranteed on regular Fargate
    },
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 0 # Additional tasks on Spot
    }
  ]

  task_count = 5 # 1 on regular Fargate, 4 on Spot

  retry_policy = {
    maximum_retry_attempts = 5
  }

  assign_public_ip   = false
  log_retention_days = 30

  tags = {
    Environment = "production"
    Priority    = "high"
    Type        = "spot-with-base"
  }
}

################################################################################
# Example 4: Regular Fargate for Comparison
# Traditional approach without Spot for critical, time-sensitive workloads
################################################################################

module "regular_fargate_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "payment-processor"
  schedule_expression = "rate(5 minutes)"
  description         = "Critical payment processor on regular Fargate"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # No capacity_provider_strategy = uses default ecs_launch_type = "FARGATE"
  # This is regular, guaranteed Fargate capacity

  task_count         = 1
  assign_public_ip   = false
  log_retention_days = 90

  tags = {
    Environment = "production"
    Critical    = "true"
    Type        = "regular-fargate"
  }
}

################################################################################
# Cost Comparison (Approximate)
################################################################################
# Assuming 1 vCPU / 2GB task running 24/7:
# - Regular Fargate: ~$35/month
# - Fargate Spot (100%): ~$10-15/month (70% savings)
# - Mixed (80% Spot): ~$15-20/month (50-60% savings)
#
# Note: Spot pricing varies by region and availability
################################################################################

################################################################################
# Outputs
################################################################################

output "fargate_spot_task_arn" {
  description = "ARN of the 100% Spot task"
  value       = module.fargate_spot_task.task_definition_arn
}

output "mixed_strategy_task_arn" {
  description = "ARN of the mixed strategy task"
  value       = module.mixed_strategy_task.task_definition_arn
}

output "spot_with_base_task_arn" {
  description = "ARN of the spot with base capacity task"
  value       = module.spot_with_base_task.task_definition_arn
}

output "regular_fargate_task_arn" {
  description = "ARN of the regular Fargate task"
  value       = module.regular_fargate_task.task_definition_arn
}

output "cost_optimization_summary" {
  description = "Summary of capacity provider strategies"
  value = {
    fargate_spot = {
      strategy     = "100% Spot"
      cost_savings = "Up to 70%"
      use_case     = "Fault-tolerant workloads"
    }
    mixed_strategy = {
      strategy     = "80% Spot, 20% Regular"
      cost_savings = "50-60%"
      use_case     = "Production workloads with high availability needs"
    }
    spot_with_base = {
      strategy     = "Base guaranteed, rest on Spot"
      cost_savings = "Variable based on task count"
      use_case     = "Critical tasks with minimum capacity requirements"
    }
    regular_fargate = {
      strategy     = "100% Regular Fargate"
      cost_savings = "0% (baseline)"
      use_case     = "Time-critical, cannot tolerate interruptions"
    }
  }
}

