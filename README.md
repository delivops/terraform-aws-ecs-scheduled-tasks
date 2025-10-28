[![DelivOps banner](https://raw.githubusercontent.com/delivops/.github/main/images/banner.png?raw=true)](https://delivops.com)

# AWS ECS Scheduled Task Terraform Module

This Terraform module deploys ECS scheduled tasks on AWS using **EventBridge Rules** (formerly CloudWatch Events) with support for Fargate and EC2 launch types.

## Features

- ✅ Creates ECS scheduled tasks with **EventBridge Rules**
- ✅ Support for both cron and rate expressions
- ✅ **Fargate Spot support** for cost savings (up to 70% cheaper)
- ✅ **Flexible capacity provider strategies** (Spot, Regular, or Mixed)
- ✅ Configurable retry policies
- ✅ Network configuration for Fargate and EC2 launch types
- ✅ CloudWatch logging integration
- ✅ Support for multiple task instances per schedule
- ✅ Custom event input (JSON) support
- ✅ Tagging support for all resources
- ✅ Task definition management with ignore changes for external deployments

## Usage

### Basic Example (Fargate)

```hcl
module "ecs_scheduled_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "my-cluster"
  name                = "data-sync"
  schedule_expression = "cron(0 12 * * ? *)" # Daily at noon UTC
  description         = "Syncs data daily at noon"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
}
```

### Example with Multiple Tasks in Same Cluster

```hcl
module "hourly_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "my-cluster"
  name                = "hourly-processor"
  schedule_expression = "rate(1 hour)"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  task_count            = 2     # Run 2 instances of the task
}

module "backup_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "my-cluster"
  name                = "backup-job"
  schedule_expression = "cron(0 3 * * ? *)"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
}
```

**Result in AWS Console:**
- Schedule Group: `my-cluster`
  - Schedule: `hourly-processor`
  - Schedule: `backup-job`


### Example with Fargate Spot (Cost Savings)

```hcl
module "fargate_spot_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "my-cluster"
  name                = "backup-job"
  schedule_expression = "rate(1 hour)"
  description         = "Hourly backup job on Spot"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  # Use 100% Fargate Spot for maximum cost savings (up to 70% cheaper)
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 0
    }
  ]
  
  # Enhanced retry policy recommended for Spot (handles interruptions)
  retry_policy = {
    maximum_retry_attempts = 3
  }
}
```

### Example with Mixed Capacity (Spot + Regular Fargate)

```hcl
module "mixed_capacity_task" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name    = "production"
  name                = "balanced-task"
  schedule_expression = "cron(0 */6 * * ? *)" # Every 6 hours
  description         = "Balanced task with mixed capacity"
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  # Mixed strategy: 70% Spot (cost savings) + 30% Regular (reliability)
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 70
      base              = 0
    },
    {
      capacity_provider = "FARGATE"
      weight            = 30
      base              = 0
    }
  ]
  
  task_count = 5  # 3-4 tasks on Spot, 1-2 on regular Fargate
}
```

## Fargate Spot vs Regular Fargate

| Feature | Regular Fargate | Fargate Spot | Mixed Strategy |
|---------|----------------|--------------|----------------|
| **Cost** | Standard pricing | Up to 70% cheaper | 30-60% cheaper |
| **Availability** | Guaranteed | Can be interrupted | Balanced |
| **Best For** | Critical, time-sensitive tasks | Fault-tolerant, flexible workloads | Production with cost awareness |
| **Interruption** | Never | 2-minute warning | Partial protection |
| **Recommendation** | Payment processing, user-facing | Data sync, batch jobs, reports | General production workloads |

### When to Use Fargate Spot

**✅ Good use cases:**
- Batch processing jobs
- Data synchronization tasks
- Report generation
- ETL pipelines
- Log processing
- Non-time-critical workloads

**❌ Avoid for:**
- Real-time payment processing
- User-facing critical operations
- Tasks that cannot tolerate 2-minute interruptions
- Stateful workloads without proper checkpointing

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
- EventBridge Rules require an IAM role with permissions to run ECS tasks
- For Fargate tasks, network mode is always "awsvpc"
- Schedule expressions use UTC timezone by default
- CPU, memory, container image, and container name should be managed in your actual task definition, not in this module
- **Event rule names must be unique per region**

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
| <a name="input_event_input"></a> [event\_input](#input\_event\_input) | JSON input to pass to the scheduled task | `string` | `""` | no |
| <a name="input_initial_role"></a> [initial\_role](#input\_initial\_role) | ARN of the IAM role to use for both task role and execution role | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs | `number` | `7` | no |
| <a name="input_retry_policy"></a> [retry\_policy](#input\_retry\_policy) | Retry policy configuration for the EventBridge target | <pre>object({<br>    maximum_retry_attempts       = optional(number, 2)<br>    maximum_event_age_in_seconds = optional(number, 3600)<br>  })</pre> | `{}` | no |
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
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch log group |
| <a name="output_event_rule_arn"></a> [event\_rule\_arn](#output\_event\_rule\_arn) | ARN of the EventBridge rule |
| <a name="output_event_rule_name"></a> [event\_rule\_name](#output\_event\_rule\_name) | Name of the EventBridge rule |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the ECS task definition |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | Family of the ECS task definition |
<!-- END_TF_DOCS -->
