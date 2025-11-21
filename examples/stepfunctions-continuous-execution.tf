###############################################################################
# Example: Step Functions Continuous Task Execution
###############################################################################
# This example demonstrates how to use Step Functions to run ECS tasks
# continuously with guaranteed intervals between executions.
#
# Key Benefits:
# - Exactly N minutes between task starts (regardless of task duration)
# - Never overlapping tasks
# - Always uses latest task definition
# - Automatic retry on failures
# - Perfect for hourly/regular processing jobs
###############################################################################

module "continuous_data_processor" {
  source = "../"
  
  # Basic Configuration
  ecs_cluster_name = "production-cluster"
  name             = "hourly-data-processor"
  description      = "Processes data every hour using Step Functions"
  
  # Use Step Functions trigger instead of EventBridge
  trigger_type = "stepfunctions"
  
  # Step Functions Configuration
  step_functions_config = {
    wait_duration_minutes = 60  # Wait 60 minutes between task starts
  }
  
  # No schedule_expression needed for Step Functions
  # schedule_expression is only used with trigger_type = "eventbridge"
  
  # Network Configuration
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-abc123", "subnet-def456"]
  security_group_ids = ["sg-11223344"]
  
  # ECS Task Configuration
  ecs_launch_type    = "FARGATE"
  assign_public_ip   = true
  platform_version   = "LATEST"
  
  # Retry Configuration
  retry_policy = {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 3600
  }
  
  # Logging
  log_retention_days = 14
  
  # State - ENABLED or DISABLED
  state = "ENABLED"  # Set to "DISABLED" to stop executions
  
  # Tags
  tags = {
    Environment = "production"
    Application = "data-processor"
    ManagedBy   = "terraform"
  }
}

###############################################################################
# Example: 15-Minute Interval
###############################################################################
module "frequent_health_check" {
  source = "../"
  
  ecs_cluster_name = "monitoring-cluster"
  name             = "health-check-15min"
  description      = "Runs health checks every 15 minutes"
  
  trigger_type = "stepfunctions"
  
  step_functions_config = {
    wait_duration_minutes = 15   # Every 15 minutes
  }
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-abc123"]
  security_group_ids = ["sg-health"]
  
  ecs_launch_type = "FARGATE"
  
  tags = {
    Purpose = "health-monitoring"
  }
}

###############################################################################
# Example: Using Fargate Spot with Step Functions
###############################################################################
module "cost_optimized_processor" {
  source = "../"
  
  ecs_cluster_name = "dev-cluster"
  name             = "spot-data-sync"
  description      = "Hourly data sync using Fargate Spot"
  
  trigger_type = "stepfunctions"
  
  step_functions_config = {
    wait_duration_minutes = 60
  }
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-abc123"]
  security_group_ids = ["sg-sync"]
  
  # Use Fargate Spot for cost savings
  capacity_provider_strategy = [{
    capacity_provider = "FARGATE_SPOT"
    weight           = 1
    base             = 0
  }]
  
  tags = {
    CostCenter = "engineering"
  }
}

###############################################################################
# Example: Disabled Step Functions (won't auto-start)
###############################################################################
module "disabled_processor" {
  source = "../"
  
  ecs_cluster_name = "staging-cluster"
  name             = "maintenance-task"
  description      = "Maintenance task - only run when needed"
  
  trigger_type = "stepfunctions"
  
  step_functions_config = {
    wait_duration_minutes = 30
  }
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-abc123"]
  security_group_ids = ["sg-maintenance"]
  
  ecs_launch_type = "FARGATE"
  
  # DISABLED - won't auto-start, start manually when needed
  state = "DISABLED"
  
  tags = {
    Purpose = "maintenance"
  }
}

###############################################################################
# Outputs
###############################################################################
output "processor_state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = module.continuous_data_processor.state_machine_arn
}

output "processor_state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = module.continuous_data_processor.state_machine_name
}

output "health_check_details" {
  description = "Details about the health check task"
  value = {
    state_machine = module.frequent_health_check.state_machine_name
    task_family   = module.frequent_health_check.task_definition_family
    log_group     = module.frequent_health_check.cloudwatch_log_group_name
  }
}

###############################################################################
# How to Enable/Disable Step Functions
###############################################################################
# The module automatically manages execution lifecycle based on the `state` variable.
#
# To ENABLE (start execution):
#   Set state = "ENABLED" in your module configuration
#   On apply, an execution will automatically start
#
# To DISABLE (stop execution):
#   Set state = "DISABLED" in your module configuration
#   On apply, running executions will be stopped
#
# Manual Control (alternative):
#   # Start execution
#   aws stepfunctions start-execution \
#     --state-machine-arn <state_machine_arn>
#
#   # Stop running executions
#   aws stepfunctions list-executions \
#     --state-machine-arn <state_machine_arn> \
#     --status-filter RUNNING \
#     --query 'executions[].executionArn' \
#     --output text | xargs -n 1 aws stepfunctions stop-execution --execution-arn
###############################################################################
