################################################################################
# Advanced Examples - Custom IAM Role
################################################################################

# Create custom IAM role with specific permissions
resource "aws_iam_role" "custom_task_role" {
  name = "scheduled-task-custom-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the custom role
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.custom_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "custom_permissions" {
  name = "custom-task-permissions"
  role = aws_iam_role.custom_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-data-bucket/*",
          "arn:aws:s3:::my-data-bucket"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:prod/*"
      }
    ]
  })
}

################################################################################
# Scheduled Task with Custom IAM Role
################################################################################

module "secure_scheduled_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  task_name           = "secure-data-processor"
  schedule_expression = "cron(0 0 * * ? *)" # Daily at midnight

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Use the custom IAM role
  initial_role = aws_iam_role.custom_task_role.arn

  # Don't assign public IP for security
  assign_public_ip = false

  log_retention_days = 30

  tags = {
    Environment = "production"
    Security    = "high"
  }
}

################################################################################
# EC2 Launch Type with Placement Constraints
################################################################################

module "ec2_scheduled_task" {
  source = "../"

  ecs_cluster_name    = "ec2-cluster"
  task_name           = "batch-processor"
  schedule_expression = "cron(0 0 * * SUN *)" # Weekly on Sunday

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Use EC2 launch type
  ecs_launch_type = "EC2"

  # EC2-specific placement constraints
  placement_constraints = [
    {
      type       = "memberOf"
      expression = "attribute:ecs.instance-type =~ t3.*"
    }
  ]

  task_count = 3

  retry_policy = {
    maximum_retry_attempts       = 1
    maximum_event_age_in_seconds = 1800
  }

  tags = {
    Environment = "production"
    LaunchType  = "EC2"
  }
}

################################################################################
# Disabled Schedule (for testing/maintenance)
################################################################################

module "disabled_scheduled_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  task_name           = "maintenance-task"
  schedule_expression = "rate(12 hours)"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Disable the schedule
  state = "DISABLED"

  tags = {
    Environment = "staging"
    Status      = "disabled"
  }
}

################################################################################
# Task with Custom EventBridge Role
################################################################################

# Create custom EventBridge execution role
resource "aws_iam_role" "custom_eventbridge_role" {
  name = "custom-eventbridge-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "custom_eventbridge_policy" {
  name = "custom-eventbridge-policy"
  role = aws_iam_role.custom_eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

module "task_with_custom_eventbridge_role" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  task_name           = "custom-role-task"
  schedule_expression = "rate(30 minutes)"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Use custom EventBridge role
  role_arn = aws_iam_role.custom_eventbridge_role.arn

  tags = {
    Environment = "production"
    CustomRole  = "true"
  }
}

################################################################################
# Multiple Tasks with Different Schedules
################################################################################

locals {
  scheduled_tasks = {
    hourly_sync = {
      schedule = "rate(1 hour)"
      count    = 1
    }
    daily_backup = {
      schedule = "cron(0 3 * * ? *)" # 3 AM daily
      count    = 1
    }
    weekly_report = {
      schedule = "cron(0 9 ? * MON *)" # Monday 9 AM
      count    = 2
    }
  }
}

module "multiple_scheduled_tasks" {
  for_each = local.scheduled_tasks
  source   = "../"

  ecs_cluster_name    = var.cluster_name
  task_name           = each.key
  schedule_expression = each.value.schedule

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  task_count = each.value.count

  tags = {
    Environment = "production"
    TaskType    = each.key
  }
}

# Expected resources:
# Each module creates:
# - 1 ECS Task Definition
# - 1 EventBridge Rule
# - 1 EventBridge Target
# - 1 CloudWatch Log Group
# - 1 IAM Role + Policy (unless custom role provided)
