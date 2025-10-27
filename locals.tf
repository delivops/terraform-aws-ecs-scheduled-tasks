locals {
  # Task definition family name
  task_family = "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.task_name}_scheduled"
  
  # EventBridge rule name
  event_rule_name = "${var.ecs_cluster_name}-${var.task_name}-scheduled-rule"
  
  # EventBridge target ID
  event_target_id = "${var.task_name}-ecs-target"
  
  # CloudWatch log group name
  log_group_name = "/ecs/scheduled/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/${var.task_name}"
  
  # EventBridge IAM role name
  eventbridge_role_name = "${var.ecs_cluster_name}-${var.task_name}-eventbridge-role"
  
  # Container definition for the initial task
  # This is a placeholder task definition that will be ignored due to lifecycle ignore_changes
  container_definitions_json = jsonencode([
    {
      name      = "placeholder"
      image     = "hello-world:latest"
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = []
    }
  ])
  
  # Network configuration for the scheduled task
  network_configuration = {
    awsvpcConfiguration = {
      subnets         = var.subnet_ids
      securityGroups  = var.security_group_ids
      assignPublicIp  = var.assign_public_ip ? "ENABLED" : "DISABLED"
    }
  }
  
  # ECS parameters for EventBridge target
  ecs_parameters = {
    taskDefinitionArn    = aws_ecs_task_definition.task_definition.arn
    launchType          = var.ecs_launch_type
    networkConfiguration = local.network_configuration
    platformVersion     = var.ecs_launch_type == "FARGATE" ? var.platform_version : null
    taskCount           = var.task_count
    group               = var.group != "" ? var.group : null
    propagateTags       = var.propagate_tags
    enableECSManagedTags = var.enable_ecs_managed_tags
    
    # Add placement constraints for EC2 launch type
    placementConstraints = var.ecs_launch_type == "EC2" && length(var.placement_constraints) > 0 ? var.placement_constraints : null
    
    # Tags for the tasks
    tags = merge(
      {
        ScheduledTask = var.task_name
        Cluster      = var.ecs_cluster_name
      },
      var.tags
    )
  }
  
  # Use provided role or create new one
  use_custom_eventbridge_role = var.role_arn != ""
  eventbridge_execution_role_arn = local.use_custom_eventbridge_role ? var.role_arn : aws_iam_role.eventbridge_role[0].arn
}
