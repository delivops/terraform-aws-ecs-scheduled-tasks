###############################################################################
# CloudWatch Log Group
###############################################################################
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  
  tags = merge(
    {
      Name          = local.log_group_name
      ScheduledTask = var.task_name
    },
    var.tags
  )
}

###############################################################################
# ECS Task Definition
###############################################################################
resource "aws_ecs_task_definition" "task_definition" {
  family                   = local.task_family
  network_mode            = var.ecs_launch_type == "FARGATE" ? "awsvpc" : "bridge"
  requires_compatibilities = [var.ecs_launch_type]
  
  # Use provided role or null (will be created by AWS)
  task_role_arn      = var.initial_role != "" ? var.initial_role : null
  execution_role_arn = var.initial_role != "" ? var.initial_role : null
  
  container_definitions = local.container_definitions_json
  
  tags = merge(
    {
      Name          = local.task_family
      ScheduledTask = var.task_name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
  
  # Ignore changes to support external deployments
  lifecycle {
    ignore_changes = all
  }
}

###############################################################################
# EventBridge (CloudWatch Events) Rule
###############################################################################
resource "aws_cloudwatch_event_rule" "scheduled_task" {
  name                = local.event_rule_name
  description         = "Trigger ECS scheduled task ${var.task_name}"
  schedule_expression = var.schedule_expression
  state               = var.state
  
  tags = merge(
    {
      Name          = local.event_rule_name
      ScheduledTask = var.task_name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
}

###############################################################################
# EventBridge Target (ECS Task)
###############################################################################
resource "aws_cloudwatch_event_target" "ecs_target" {
  rule      = aws_cloudwatch_event_rule.scheduled_task.name
  target_id = local.event_target_id
  arn       = data.aws_ecs_cluster.ecs_cluster.arn
  role_arn  = local.eventbridge_execution_role_arn
  
  # Optional event input
  input = var.event_input != "" ? var.event_input : null
  
  # ECS task parameters
  ecs_target {
    task_definition_arn = aws_ecs_task_definition.task_definition.arn
    launch_type        = var.ecs_launch_type
    task_count         = var.task_count
    platform_version   = var.ecs_launch_type == "FARGATE" ? var.platform_version : null
    group              = var.group != "" ? var.group : null
    
    # Network configuration
    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = var.security_group_ids
      assign_public_ip = var.assign_public_ip
    }
    
    # Placement constraints for EC2
    dynamic "placement_constraint" {
      for_each = var.ecs_launch_type == "EC2" ? var.placement_constraints : []
      content {
        type       = placement_constraint.value.type
        expression = placement_constraint.value.expression
      }
    }
    
    propagate_tags          = var.propagate_tags
    enable_ecs_managed_tags = var.enable_ecs_managed_tags
    
    tags = merge(
      {
        ScheduledTask = var.task_name
        Cluster       = var.ecs_cluster_name
        EventRule     = local.event_rule_name
      },
      var.tags
    )
  }
  
  # Retry policy configuration
  retry_policy {
    maximum_retry_attempts       = var.retry_policy.maximum_retry_attempts
    maximum_event_age_in_seconds = var.retry_policy.maximum_event_age_in_seconds
  }
  
  depends_on = [
    aws_ecs_task_definition.task_definition,
    aws_iam_role_policy.eventbridge_policy
  ]
}

###############################################################################
# IAM Role for EventBridge to execute ECS tasks
###############################################################################
resource "aws_iam_role" "eventbridge_role" {
  count = local.use_custom_eventbridge_role ? 0 : 1
  
  name = local.eventbridge_role_name
  
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
  
  tags = merge(
    {
      Name          = local.eventbridge_role_name
      ScheduledTask = var.task_name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
}

###############################################################################
# IAM Policy for EventBridge role
###############################################################################
resource "aws_iam_role_policy" "eventbridge_policy" {
  count = local.use_custom_eventbridge_role ? 0 : 1
  
  name = "${local.eventbridge_role_name}-policy"
  role = aws_iam_role.eventbridge_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/${local.task_family}:*"
        ]
        Condition = {
          StringEquals = {
            "ecs:cluster" = data.aws_ecs_cluster.ecs_cluster.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.initial_role != "" ? [var.initial_role] : ["*"]
        Condition = var.initial_role == "" ? {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        } : null
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs_log_group.arn}:*"
      }
    ]
  })
}
