################################################################################
# Module Validation Tests
# This file can be used to validate the module works correctly
################################################################################

################################################################################
# Test 1: Minimal Required Configuration
################################################################################

module "test_minimal" {
  source = "../"

  ecs_cluster_name    = "test-cluster"
  task_name           = "test-minimal"
  schedule_expression = "rate(1 hour)"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-12345678"]
}

################################################################################
# Test 2: All Optional Parameters
################################################################################

module "test_full_config" {
  source = "../"

  # Required parameters
  ecs_cluster_name    = "test-cluster"
  task_name           = "test-full"
  schedule_expression = "cron(0 12 * * ? *)"
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-12345678", "sg-87654321"]

  # Optional parameters
  ecs_launch_type    = "FARGATE"
  assign_public_ip   = true
  initial_role       = ""
  task_count         = 2
  log_retention_days = 14
  state              = "ENABLED"
  platform_version   = "LATEST"
  propagate_tags     = "TASK_DEFINITION"
  enable_ecs_managed_tags = true
  group              = "test-group"

  retry_policy = {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 7200
  }

  event_input = jsonencode({
    test = "data"
    nested = {
      value = 123
    }
  })

  placement_constraints = []

  tags = {
    Test        = "true"
    Environment = "test"
    Module      = "ecs-scheduled-task"
  }
}

################################################################################
# Test 3: EC2 Launch Type
################################################################################

module "test_ec2_launch" {
  source = "../"

  ecs_cluster_name    = "ec2-cluster"
  task_name           = "test-ec2"
  schedule_expression = "rate(30 minutes)"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]

  ecs_launch_type = "EC2"
  
  placement_constraints = [
    {
      type       = "memberOf"
      expression = "attribute:ecs.instance-type =~ t3.*"
    }
  ]

  # Note: For EC2, network_mode will be "bridge" instead of "awsvpc"
  # and certain parameters like assign_public_ip won't apply
}

################################################################################
# Test 4: Rate vs Cron Expressions
################################################################################

module "test_rate_expression" {
  source = "../"

  ecs_cluster_name    = "test-cluster"
  task_name           = "test-rate"
  schedule_expression = "rate(5 minutes)"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]
}

module "test_cron_expression" {
  source = "../"

  ecs_cluster_name    = "test-cluster"  
  task_name           = "test-cron"
  schedule_expression = "cron(0 12 * * ? *)"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]
}

################################################################################
# Test 5: Different Task Counts
################################################################################

locals {
  task_counts = [1, 2, 5, 10]
}

module "test_task_counts" {
  for_each = toset([for i in local.task_counts : tostring(i)])
  source   = "../"

  ecs_cluster_name    = "test-cluster"
  task_name           = "test-count-${each.value}"
  schedule_expression = "rate(1 hour)"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]

  task_count = tonumber(each.value)
}

################################################################################
# Test 6: State Management
################################################################################

module "test_enabled_task" {
  source = "../"

  ecs_cluster_name    = "test-cluster"
  task_name           = "test-enabled"
  schedule_expression = "rate(1 hour)"
  state               = "ENABLED"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]
}

module "test_disabled_task" {
  source = "../"

  ecs_cluster_name    = "test-cluster"
  task_name           = "test-disabled"
  schedule_expression = "rate(1 hour)"
  state               = "DISABLED"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]
}

################################################################################
# Test 7: Custom IAM Roles
################################################################################

resource "aws_iam_role" "test_task_role" {
  name = "test-scheduled-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role" "test_eventbridge_role" {
  name = "test-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

module "test_custom_iam" {
  source = "../"

  ecs_cluster_name    = "test-cluster"
  task_name           = "test-custom-iam"
  schedule_expression = "rate(1 hour)"
  
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]

  initial_role = aws_iam_role.test_task_role.arn
  role_arn     = aws_iam_role.test_eventbridge_role.arn
}

################################################################################
# Expected Outputs Validation
################################################################################

output "test_minimal_outputs" {
  value = {
    task_definition_arn        = module.test_minimal.task_definition_arn
    task_definition_family     = module.test_minimal.task_definition_family
    event_rule_name            = module.test_minimal.event_rule_name
    event_rule_arn             = module.test_minimal.event_rule_arn
    cloudwatch_log_group_name  = module.test_minimal.cloudwatch_log_group_name
    cloudwatch_log_group_arn   = module.test_minimal.cloudwatch_log_group_arn
    eventbridge_role_arn       = module.test_minimal.eventbridge_role_arn
    event_target_id            = module.test_minimal.event_target_id
    schedule_expression        = module.test_minimal.schedule_expression
    task_details               = module.test_minimal.task_details
  }
  
  description = "All outputs from the minimal configuration test"
}

# Validation Rules:
# 1. Each module should create exactly 4-5 resources (depending on IAM role)
# 2. Task definition should be created with lifecycle ignore_changes
# 3. EventBridge rule should be created with the specified schedule
# 4. EventBridge target should link the rule to the ECS task
# 5. CloudWatch log group should be created for task logs
# 6. IAM role should be created if not provided
