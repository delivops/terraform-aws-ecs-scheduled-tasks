###############################################################################
# Step Functions State Machine for Continuous Task Execution
###############################################################################

###############################################################################
# IAM Role for Step Functions
###############################################################################
resource "aws_iam_role" "sfn_role" {
  count = local.use_step_functions ? 1 : 0
  
  name = local.sfn_role_name
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
  
  tags = merge(
    {
      Name          = local.sfn_role_name
      ScheduledTask = var.name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
}

###############################################################################
# IAM Policy for Step Functions to Run ECS Tasks
###############################################################################
resource "aws_iam_role_policy" "sfn_policy" {
  count = local.use_step_functions ? 1 : 0
  
  name = "${local.sfn_role_name}-policy"
  role = aws_iam_role.sfn_role[0].id
  
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
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = [
          "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
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

###############################################################################
# Step Functions State Machine Definition
###############################################################################
resource "aws_sfn_state_machine" "ecs_task_loop" {
  count = local.use_step_functions ? 1 : 0
  
  name     = local.state_machine_name
  role_arn = aws_iam_role.sfn_role[0].arn
  
  definition = jsonencode({
    Comment = "Continuous ECS task execution with guaranteed ${var.step_functions_config.wait_duration_minutes} minute intervals"
    StartAt = "ParallelExecution"
    States = {
      
      # Parallel execution: Task + Wait
      ParallelExecution = {
        Type    = "Parallel"
        Comment = "Run ECS task while simultaneously waiting for ${var.step_functions_config.wait_duration_minutes} minutes"
        Branches = [
          # Branch 1: Run the ECS Task
          {
            StartAt = "RunECSTask"
            States = {
              RunECSTask = {
                Type     = "Task"
                Resource = "arn:aws:states:::ecs:runTask.sync"
                Parameters = {
                  Cluster        = data.aws_ecs_cluster.ecs_cluster.arn
                  TaskDefinition = aws_ecs_task_definition.task_definition.family
                  LaunchType     = length(var.capacity_provider_strategy) == 0 ? var.ecs_launch_type : null
                  
                  # Use capacity provider strategy if provided
                  CapacityProviderStrategy = length(var.capacity_provider_strategy) > 0 ? [
                    for cp in var.capacity_provider_strategy : {
                      CapacityProvider = cp.capacity_provider
                      Weight           = cp.weight
                      Base             = cp.base
                    }
                  ] : null
                  
                  PlatformVersion = local.is_fargate ? var.platform_version : null
                  
                  NetworkConfiguration = {
                    AwsvpcConfiguration = {
                      Subnets        = var.subnet_ids
                      SecurityGroups = var.security_group_ids
                      AssignPublicIp = var.assign_public_ip ? "ENABLED" : "DISABLED"
                    }
                  }
                  
                  PropagateTags = var.propagate_tags
                  
                  Tags = [
                    for key, value in merge(
                      {
                        ScheduledTask  = var.name
                        Cluster        = var.ecs_cluster_name
                        TriggerType    = "stepfunctions"
                        StateMachine   = local.state_machine_name
                      },
                      var.tags
                    ) : {
                      Key   = key
                      Value = value
                    }
                  ]
                }
                End     = true
                Retry = [
                  {
                    ErrorEquals = [
                      "States.TaskFailed",
                      "States.Timeout"
                    ]
                    IntervalSeconds = 30
                    MaxAttempts     = var.retry_policy.maximum_retry_attempts
                    BackoffRate     = 2.0
                  }
                ]
                Catch = [
                  {
                    ErrorEquals = ["States.ALL"]
                    ResultPath  = "$.error"
                    Next        = "TaskFailed"
                  }
                ]
              }
              
              TaskFailed = {
                Type = "Pass"
                Comment = "Task failed but continue loop"
                End  = true
              }
            }
          },
          
          # Branch 2: Wait for specified duration
          {
            StartAt = "WaitInterval"
            States = {
              WaitInterval = {
                Type    = "Wait"
                Seconds = var.step_functions_config.wait_duration_minutes * 60
                Comment = "Wait for ${var.step_functions_config.wait_duration_minutes} minutes"
                End     = true
              }
            }
          }
        ]
        Next = "ParallelExecution"
      }
    }
  })
  
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_log_group[0].arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }
  
  tags = merge(
    {
      Name          = local.state_machine_name
      ScheduledTask = var.name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
  
  depends_on = [
    aws_iam_role_policy.sfn_policy,
    aws_ecs_task_definition.task_definition
  ]
}

###############################################################################
# CloudWatch Log Group for Step Functions
###############################################################################
resource "aws_cloudwatch_log_group" "sfn_log_group" {
  count = local.use_step_functions ? 1 : 0
  
  name              = "/aws/vendedlogs/states/${local.state_machine_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(
    {
      Name          = "/aws/vendedlogs/states/${local.state_machine_name}"
      ScheduledTask = var.name
      Cluster       = var.ecs_cluster_name
    },
    var.tags
  )
}

###############################################################################
# Auto-Start Execution (respects state variable)
###############################################################################
resource "terraform_data" "sfn_execution_manager" {
  count = local.use_step_functions ? 1 : 0
  
  triggers_replace = {
    state_machine_arn = aws_sfn_state_machine.ecs_task_loop[0].arn
    state             = var.state
  }
  
  # Start execution when ENABLED
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      if [ "${var.state}" = "ENABLED" ]; then
        echo "Starting Step Functions execution..."
        aws stepfunctions start-execution \
          --state-machine-arn "${aws_sfn_state_machine.ecs_task_loop[0].arn}" \
          --name "${local.state_machine_name}-auto-$(date +%Y%m%d-%H%M%S)" || echo "Execution may already be running"
      else
        echo "Step Functions state is DISABLED - not starting execution"
      fi
    EOT
  }
  
  # Stop running executions when destroyed or DISABLED
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Stopping Step Functions executions..."
      aws stepfunctions list-executions \
        --state-machine-arn "${self.triggers_replace.state_machine_arn}" \
        --status-filter RUNNING \
        --query 'executions[].executionArn' \
        --output text | xargs -r -n 1 aws stepfunctions stop-execution --execution-arn || true
    EOT
  }
}
