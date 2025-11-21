[![DelivOps banner](https://raw.githubusercontent.com/delivops/.github/main/images/banner.png?raw=true)](https://delivops.com)

# AWS ECS Scheduled Task Terraform Module

This Terraform module deploys ECS scheduled tasks on AWS using **EventBridge Rules** (formerly CloudWatch Events) with support for Fargate and EC2 launch types.

## Features

- ✅ **Two trigger modes**: EventBridge Rules or Step Functions
- ✅ Creates ECS scheduled tasks with **EventBridge Rules**
- ✅ **Step Functions continuous execution** with guaranteed intervals
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

## Step Functions Continuous Execution

For workloads that need **guaranteed intervals** between task starts, use the Step Functions trigger mode. This provides a perfect metronome that ensures tasks start at regular intervals regardless of task duration.

### Step Functions vs EventBridge

| Feature | EventBridge Rules | Step Functions Loop |
|---------|------------------|---------------------|
| **Scheduling** | Cron or rate expression | Fixed wait duration between starts |
| **Interval Guarantee** | Based on schedule time | Guaranteed N minutes between starts |
| **Overlapping Tasks** | Possible if task runs long | Never - waits for task completion |
| **Task Duration Impact** | None (schedule is independent) | Next start waits for completion |
| **Use Latest Code** | Yes | Yes (always uses latest task definition) |
| **Best For** | Time-based schedules | Regular interval processing |
| **Iterations** | Infinite | Configurable (infinite or limited) |

### Step Functions Example

```hcl
module "continuous_processor" {
  source = "delivops/ecs-scheduled-task/aws"
  
  ecs_cluster_name = "my-cluster"
  name             = "hourly-processor"
  description      = "Processes data every hour using Step Functions"
  
  # Use Step Functions instead of EventBridge
  trigger_type = "stepfunctions"
  
  # Configure the wait duration between task starts
  step_functions_config = {
    wait_duration_minutes = 60  # Wait 60 minutes between task starts
  }
  
  # No schedule_expression needed for Step Functions
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  ecs_launch_type = "FARGATE"
}
```

### How It Works

**Parallel State Design:**
```
Parallel State:
├── Branch 1: Run ECS Task (your actual work)
└── Branch 2: Wait N minutes
→ When BOTH complete → Loop back to start
```

**Execution Timeline Example (60-minute interval):**
- **Iteration 1**: Task runs 45 min | Wait 60 min → Next starts at 60 min
- **Iteration 2**: Task runs 58 min | Wait 60 min → Next starts at 60 min  
- **Iteration 3**: Task runs 35 min | Wait 60 min → Next starts at 60 min
- **Iteration 4**: Task runs 62 min | Wait 60 min → Next starts at 62 min

**Key Guarantees:**
- ✅ Exactly N minutes between starts (when task < N minutes)
- ✅ Never overlapping - next task only starts after both branches complete
- ✅ Always uses latest task definition on each iteration
- ✅ Perfect for hourly/regular processing jobs

### Starting the Step Functions Execution

The Step Functions state machine needs to be started manually or programmatically:

**Option 1: AWS CLI**
```bash
aws stepfunctions start-execution \
  --state-machine-arn <state_machine_arn> \
  --input '{"loopCount": 0}'
```

**Option 2: AWS Console**
Navigate to Step Functions console and click "Start execution"

**Option 3: Terraform**
```hcl
resource "aws_sfn_execution" "start_processor" {
  state_machine_arn = module.continuous_processor.state_machine_arn
  input = jsonencode({
    loopCount = 0
  })
}
```

**Option 4: Lambda or Another Service**
Create a Lambda function or use another service to start the execution programmatically.

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
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.eventbridge_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign public IP to ECS tasks (Fargate only) | `bool` | `false` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | Capacity provider strategy for the ECS task. Use this for Fargate Spot. If set, overrides ecs\_launch\_type. Example: [{ capacity\_provider = "FARGATE\_SPOT", weight = 1, base = 0 }] | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = optional(number)<br/>    base              = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the scheduled task. If not provided, a default description will be generated. | `string` | `""` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_ecs_launch_type"></a> [ecs\_launch\_type](#input\_ecs\_launch\_type) | Launch type for the ECS task (FARGATE or EC2). Ignored if capacity\_provider\_strategy is set. | `string` | `"FARGATE"` | no |
| <a name="input_enable_ecs_managed_tags"></a> [enable\_ecs\_managed\_tags](#input\_enable\_ecs\_managed\_tags) | Enable ECS managed tags for the tasks | `bool` | `true` | no |
| <a name="input_event_input"></a> [event\_input](#input\_event\_input) | JSON input to pass to the scheduled task | `string` | `""` | no |
| <a name="input_group"></a> [group](#input\_group) | Group name for the scheduled tasks | `string` | `""` | no |
| <a name="input_initial_role"></a> [initial\_role](#input\_initial\_role) | ARN of the IAM role to use for both task role and execution role | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs | `number` | `7` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the scheduled task | `string` | n/a | yes |
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
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#output\_capacity\_provider\_strategy) | Capacity provider strategy configuration (empty if using launch\_type) |
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
| <a name="output_task_execution_role_arn"></a> [task\_execution\_role\_arn](#output\_task\_execution\_role\_arn) | ARN of the ECS Task Execution role (if created) |
<!-- END_TF_DOCS -->
