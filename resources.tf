###############################################################################
# CloudWatch Log Group
###############################################################################
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  
  tags = merge(
    {
      Name          = local.log_group_name
      ScheduledTask = var.name
    },
    var.tags
  )
}

###############################################################################
# ECS Task Execution Role (required for Fargate)
###############################################################################
resource "aws_iam_role" "task_execution_role" {
  count = var.initial_role == "" ? 1 : 0
  
  name = "${var.ecs_cluster_name}-${var.name}-execution-role"
  
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
  
  tags = merge(
    {
      Name          = "${var.ecs_cluster_name}-${var.name}-execution-role"
      ScheduledTask = var.name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  count = var.initial_role == "" ? 1 : 0
  
  role       = aws_iam_role.task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###############################################################################
# ECS Task Definition
###############################################################################
resource "aws_ecs_task_definition" "task_definition" {
  family                   = local.task_family
  network_mode            = local.is_fargate ? "awsvpc" : "bridge"
  requires_compatibilities = [local.requires_compatibility]
  
  # CPU and Memory required for Fargate
  cpu    = local.is_fargate ? "256" : null
  memory = local.is_fargate ? "512" : null
  
  # Use provided role or created execution role
  task_role_arn      = var.initial_role != "" ? var.initial_role : null
  execution_role_arn = var.initial_role != "" ? var.initial_role : try(aws_iam_role.task_execution_role[0].arn, null)
  
  container_definitions = local.container_definitions_json
  
  tags = merge(
    {
      Name          = local.task_family
      ScheduledTask = var.name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
  
  # Ignore changes to support external deployments
  lifecycle {
    ignore_changes = all
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.task_execution_policy
  ]
}

###############################################################################
# EventBridge (CloudWatch Events) Rule
###############################################################################
resource "aws_cloudwatch_event_rule" "scheduled_task" {
  name                = local.event_rule_name
  description         = local.task_description
  schedule_expression = var.schedule_expression
  state               = var.state
  
  tags = merge(
    {
      Name          = local.event_rule_name
      ScheduledTask = var.name
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
    
    # Use capacity_provider_strategy if provided, otherwise use launch_type
    launch_type      = length(var.capacity_provider_strategy) == 0 ? var.ecs_launch_type : null
    task_count       = var.task_count
    platform_version = local.is_fargate ? var.platform_version : null
    group            = var.group != "" ? var.group : null
    
    # Capacity provider strategy (for Fargate Spot or custom strategies)
    dynamic "capacity_provider_strategy" {
      for_each = var.capacity_provider_strategy
      content {
        capacity_provider = capacity_provider_strategy.value.capacity_provider
        weight            = capacity_provider_strategy.value.weight
        base              = capacity_provider_strategy.value.base
      }
    }
    
    # Network configuration
    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = var.security_group_ids
      assign_public_ip = var.assign_public_ip
    }
    
    propagate_tags          = var.propagate_tags
    enable_ecs_managed_tags = var.enable_ecs_managed_tags
    
    tags = merge(
      {
        ScheduledTask = var.name
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

  lifecycle {
    ignore_changes = [
      ecs_target[0].task_definition_arn
    ]
  } 
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
      ScheduledTask = var.name
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
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.task_family}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          data.aws_ecs_cluster.ecs_cluster.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:TagResource"
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.initial_role != "" ? [var.initial_role] : [
          try(aws_iam_role.task_execution_role[0].arn, "*")
        ]
        Condition = {
          StringLike = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
  
  depends_on = [
    aws_iam_role.task_execution_role
  ]
}
