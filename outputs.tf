output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.task_definition.arn
}

output "task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.task_definition.family
}

output "event_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.scheduled_task.name
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.scheduled_task.arn
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
  description = "ARN of the EventBridge IAM role (if created)"
  value       = local.use_custom_eventbridge_role ? var.role_arn : try(aws_iam_role.eventbridge_role[0].arn, "")
}

output "event_target_id" {
  description = "ID of the EventBridge target"
  value       = aws_cloudwatch_event_target.ecs_target.target_id
}

output "schedule_expression" {
  description = "Schedule expression for the task"
  value       = var.schedule_expression
}

output "task_details" {
  description = "Details about the scheduled task configuration"
  value = {
    cluster_name     = var.ecs_cluster_name
    task_name        = var.task_name
    launch_type      = var.ecs_launch_type
    task_count       = var.task_count
    schedule         = var.schedule_expression
    state            = var.state
    retry_attempts   = var.retry_policy.maximum_retry_attempts
  }
}
