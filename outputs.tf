output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.task_definition.arn
}

output "task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.task_definition.family
}

output "event_rule_name" {
  description = "Name of the EventBridge rule (only for eventbridge trigger_type)"
  value       = local.use_eventbridge ? aws_cloudwatch_event_rule.scheduled_task[0].name : null
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule (only for eventbridge trigger_type)"
  value       = local.use_eventbridge ? aws_cloudwatch_event_rule.scheduled_task[0].arn : null
}

output "event_target_id" {
  description = "ID of the EventBridge target (only for eventbridge trigger_type)"
  value       = local.use_eventbridge ? aws_cloudwatch_event_target.ecs_target[0].target_id : null
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_log_group.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_log_group.arn
}

output "eventbridge_role_arn" {
  description = "ARN of the EventBridge IAM role (only for eventbridge trigger_type)"
  value       = local.use_eventbridge ? (local.use_custom_eventbridge_role ? var.role_arn : try(aws_iam_role.eventbridge_role[0].arn, "")) : null
}

output "task_execution_role_arn" {
  description = "ARN of the ECS Task Execution role (if created)"
  value       = var.initial_role != "" ? var.initial_role : try(aws_iam_role.task_execution_role[0].arn, "")
}

output "schedule_expression" {
  description = "Schedule expression for the task (only for eventbridge trigger_type)"
  value       = local.use_eventbridge ? var.schedule_expression : null
}

output "task_details" {
  description = "Details about the scheduled task configuration"
  value = {
    cluster_name              = var.ecs_cluster_name
    task_name                 = var.name
    event_rule_name           = local.event_rule_name
    launch_type               = length(var.capacity_provider_strategy) == 0 ? var.ecs_launch_type : "capacity_provider"
    capacity_provider_enabled = length(var.capacity_provider_strategy) > 0
    task_count                = var.task_count
    schedule                  = var.schedule_expression
    state                     = var.state
    retry_attempts            = var.retry_policy.maximum_retry_attempts
  }
}

output "capacity_provider_strategy" {
  description = "Capacity provider strategy configuration (empty if using launch_type)"
  value       = var.capacity_provider_strategy
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine (only for stepfunctions trigger_type)"
  value       = local.use_step_functions ? aws_sfn_state_machine.ecs_task_loop[0].arn : null
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine (only for stepfunctions trigger_type)"
  value       = local.use_step_functions ? aws_sfn_state_machine.ecs_task_loop[0].name : null
}

output "sfn_role_arn" {
  description = "ARN of the Step Functions IAM role (only for stepfunctions trigger_type)"
  value       = local.use_step_functions ? aws_iam_role.sfn_role[0].arn : null
}

output "sfn_log_group_name" {
  description = "Name of the Step Functions CloudWatch log group (only for stepfunctions trigger_type)"
  value       = local.use_step_functions ? aws_cloudwatch_log_group.sfn_log_group[0].name : null
}

output "trigger_type" {
  description = "Type of trigger configured for this task"
  value       = var.trigger_type
}
