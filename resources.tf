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
