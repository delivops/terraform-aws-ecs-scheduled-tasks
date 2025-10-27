[![DelivOps banner](https://raw.githubusercontent.com/delivops/.github/main/images/banner.png?raw=true)](https://delivops.com)

# AWS ECS Scheduled Task Terraform Module

This Terraform module deploys ECS scheduled tasks on AWS using EventBridge (CloudWatch Events) with support for Fargate and EC2 launch types.

## Features

- Creates ECS scheduled tasks with EventBridge/CloudWatch Events triggers
- Support for both cron and rate expressions
- Configurable retry policies with exponential backoff
- Network configuration for Fargate and EC2 launch types
- CloudWatch logging integration
- Support for multiple task instances per schedule
- Custom event input (JSON) support
- Tagging support for all resources
- Task definition management with ignore changes for external deployments

## Resources Created

- ECS Task Definition
- EventBridge Rule (CloudWatch Events)
- EventBridge Target
- CloudWatch Log Group
- IAM Role for EventBridge execution (if not provided)

## Usage

### Basic Example (Fargate)

```hcl
module "ecs_scheduled_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name = "my-cluster"
  task_name        = "my-scheduled-task"
  schedule_expression = "cron(0 12 * * ? *)" # Daily at noon UTC
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
}
```

### Example with Rate Expression

```hcl
module "hourly_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "my-cluster"
  task_name          = "hourly-processor"
  schedule_expression = "rate(1 hour)"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  task_count = 2  # Run 2 instances of the task
}
```

### Example with Retry Policy

```hcl
module "data_processor" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "production"
  task_name          = "data-processor"
  schedule_expression = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  retry_policy = {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 3600
  }
  
  tags = {
    Environment = "production"
    Team        = "data"
  }
}
```

### Example with Event Input

```hcl
module "etl_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "analytics"
  task_name          = "etl-pipeline"
  schedule_expression = "cron(0 6 * * MON-FRI *)" # Weekdays at 6 AM
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  event_input = jsonencode({
    source = "s3",
    bucket = "my-data-bucket",
    prefix = "raw-data/"
  })
  
  task_count = 1
}
```

### Example with Custom IAM Role

```hcl
module "secure_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "secure-cluster"
  task_name          = "secure-processor"
  schedule_expression = "rate(30 minutes)"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  initial_role = aws_iam_role.custom_task_role.arn
  
  assign_public_ip = false
  
  log_retention_days = 30
}
```

### Example with EC2 Launch Type

```hcl
module "ec2_scheduled_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "ec2-cluster"
  task_name          = "batch-job"
  schedule_expression = "cron(0 0 * * SUN *)" # Weekly on Sunday
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  ecs_launch_type = "EC2"
}
```

## Schedule Expression Examples

### Cron Expressions
- `cron(0 12 * * ? *)` - Every day at noon UTC
- `cron(0 18 ? * MON-FRI *)` - Every weekday at 6 PM UTC
- `cron(0/5 * * * ? *)` - Every 5 minutes
- `cron(0 0 1 * ? *)` - First day of every month at midnight

### Rate Expressions
- `rate(5 minutes)` - Every 5 minutes
- `rate(1 hour)` - Every hour
- `rate(7 days)` - Every 7 days

## Notes

- The module creates an initial placeholder task definition that will be overridden
- Task definition changes are ignored to support external deployments
- EventBridge requires an IAM role with permissions to run ECS tasks
- For Fargate tasks, network mode is always "awsvpc"
- Schedule expressions use UTC timezone
- CPU, memory, container image, and container name should be managed in your actual task definition, not in this module

## License

This module is released under the MIT License.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.scheduled_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.ecs_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.eventbridge_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.eventbridge_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign public IP to ECS tasks (Fargate only) | `bool` | `false` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_ecs_launch_type"></a> [ecs\_launch\_type](#input\_ecs\_launch\_type) | Launch type for the ECS task (FARGATE or EC2) | `string` | `"FARGATE"` | no |
| <a name="input_enable_ecs_managed_tags"></a> [enable\_ecs\_managed\_tags](#input\_enable\_ecs\_managed\_tags) | Enable ECS managed tags for the tasks | `bool` | `true` | no |
| <a name="input_event_input"></a> [event\_input](#input\_event\_input) | JSON input to pass to the scheduled task | `string` | `""` | no |
| <a name="input_group"></a> [group](#input\_group) | Group name for the scheduled tasks | `string` | `""` | no |
| <a name="input_initial_role"></a> [initial\_role](#input\_initial\_role) | ARN of the IAM role to use for both task role and execution role | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs | `number` | `7` | no |
| <a name="input_placement_constraints"></a> [placement\_constraints](#input\_placement\_constraints) | Placement constraints for EC2 launch type | <pre>list(object({<br/>    type       = string<br/>    expression = string<br/>  }))</pre> | `[]` | no |
| <a name="input_platform_version"></a> [platform\_version](#input\_platform\_version) | Platform version for Fargate tasks | `string` | `"LATEST"` | no |
| <a name="input_propagate_tags"></a> [propagate\_tags](#input\_propagate\_tags) | Propagate tags from the task definition or the service to the tasks | `string` | `"TASK_DEFINITION"` | no |
| <a name="input_retry_policy"></a> [retry\_policy](#input\_retry\_policy) | Retry policy configuration for the EventBridge target | <pre>object({<br/>    maximum_retry_attempts       = optional(number, 2)<br/>    maximum_event_age_in_seconds = optional(number, 3600)<br/>  })</pre> | `{}` | no |
| <a name="input_role_arn"></a> [role\_arn](#input\_role\_arn) | ARN of the IAM role that EventBridge assumes to run the task | `string` | `""` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Schedule expression for the task (cron or rate) | `string` | n/a | yes |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs for the ECS tasks | `list(string)` | n/a | yes |
| <a name="input_state"></a> [state](#input\_state) | State of the EventBridge rule (ENABLED or DISABLED) | `string` | `"ENABLED"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the ECS tasks | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_task_count"></a> [task\_count](#input\_task\_count) | Number of tasks to run per scheduled execution | `number` | `1` | no |
| <a name="input_task_name"></a> [task\_name](#input\_task\_name) | Name of the scheduled task | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | ARN of the CloudWatch log group |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch log group |
| <a name="output_event_rule_arn"></a> [event\_rule\_arn](#output\_event\_rule\_arn) | ARN of the EventBridge rule |
| <a name="output_event_rule_name"></a> [event\_rule\_name](#output\_event\_rule\_name) | Name of the EventBridge rule |
| <a name="output_event_target_id"></a> [event\_target\_id](#output\_event\_target\_id) | ID of the EventBridge target |
| <a name="output_eventbridge_role_arn"></a> [eventbridge\_role\_arn](#output\_eventbridge\_role\_arn) | ARN of the EventBridge IAM role (if created) |
| <a name="output_schedule_expression"></a> [schedule\_expression](#output\_schedule\_expression) | Schedule expression for the task |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the ECS task definition |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | Family of the ECS task definition |
| <a name="output_task_details"></a> [task\_details](#output\_task\_details) | Details about the scheduled task configuration |
<!-- END_TF_DOCS -->
