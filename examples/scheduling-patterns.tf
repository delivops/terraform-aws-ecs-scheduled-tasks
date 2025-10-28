################################################################################
# Complex Scheduling Patterns Examples
# This file demonstrates various scheduling patterns for ECS tasks
################################################################################

################################################################################
# Business Hours Only (9 AM - 5 PM on weekdays)
################################################################################

module "business_hours_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "business-hours-processor"
  schedule_expression = "cron(0 9-17 ? * MON-FRI *)" # Every hour from 9 AM to 5 PM on weekdays

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  event_input = jsonencode({
    mode = "business_hours"
    timezone = "UTC"
  })

  tags = {
    Schedule = "BusinessHours"
    Type     = "Processor"
  }
}

################################################################################
# End of Month Processing (Last day of each month)
################################################################################

module "end_of_month_task" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "month-end-reconciliation"
  schedule_expression = "cron(0 23 L * ? *)" # Last day of month at 11 PM

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  retry_policy = {
    maximum_retry_attempts       = 5
    maximum_event_age_in_seconds = 7200 # 2 hours
  }

  event_input = jsonencode({
    task_type = "month_end_close"
    notifications = {
      on_success = "finance-team@example.com"
      on_failure = "ops-team@example.com"
    }
  })

  log_retention_days = 90 # Keep logs for compliance

  tags = {
    Schedule   = "MonthEnd"
    Department = "Finance"
    Compliance = "Required"
  }
}

################################################################################
# Quarterly Reports (First Monday of each quarter)
################################################################################

module "quarterly_reports" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "quarterly-report-generator"
  # First Monday of Jan, Apr, Jul, Oct
  schedule_expression = "cron(0 6 ? 1,4,7,10 MON#1 *)" 

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  task_count = 1

  event_input = jsonencode({
    report_type = "quarterly_summary"
    output_bucket = "company-reports"
    distribution_list = ["executives@example.com", "board@example.com"]
  })

  log_retention_days = 365 # Keep for a year

  tags = {
    Schedule = "Quarterly"
    Type     = "Reporting"
    Priority = "High"
  }
}

################################################################################
# Peak Hours Scaling (Different schedules for peak vs off-peak)
################################################################################

# Peak hours task (8 AM - 8 PM)
module "peak_hours_processor" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "peak-traffic-handler"
  schedule_expression = "cron(*/10 8-20 * * ? *)" # Every 10 minutes during peak hours

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  task_count = 3 # More instances during peak

  event_input = jsonencode({
    mode = "peak"
    batch_size = 1000
  })

  tags = {
    Schedule = "PeakHours"
    LoadType = "High"
  }
}

# Off-peak hours task (8 PM - 8 AM)
module "off_peak_processor" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "off-peak-handler"
  schedule_expression = "cron(0 20-23,0-8 * * ? *)" # Every hour during off-peak

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  task_count = 1 # Fewer instances during off-peak

  event_input = jsonencode({
    mode = "off_peak"
    batch_size = 100
  })

  tags = {
    Schedule = "OffPeak"
    LoadType = "Low"
  }
}

################################################################################
# Weekend Maintenance Window (Saturday 2-4 AM)
################################################################################

module "weekend_maintenance" {
  source = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "weekend-maintenance"
  schedule_expression = "cron(0 2-4 ? * SAT *)" # Every hour from 2-4 AM on Saturday

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  event_input = jsonencode({
    maintenance_tasks = [
      "database_optimization",
      "cache_cleanup",
      "log_rotation",
      "backup_verification"
    ]
    alert_channel = "ops-oncall"
  })

  retry_policy = {
    maximum_retry_attempts       = 2
    maximum_event_age_in_seconds = 3600
  }

  tags = {
    Schedule        = "WeekendMaintenance"
    MaintenanceType = "Routine"
  }
}

################################################################################
# Multiple Schedules for Same Task (Using for_each)
################################################################################

locals {
  data_sync_schedules = {
    morning_sync = {
      schedule    = "cron(0 7 * * ? *)"      # 7 AM daily
      task_count  = 2
      environment = "production"
    }
    noon_sync = {
      schedule    = "cron(0 12 * * ? *)"     # Noon daily
      task_count  = 1
      environment = "production"
    }
    evening_sync = {
      schedule    = "cron(0 19 * * ? *)"     # 7 PM daily
      task_count  = 2
      environment = "production"
    }
    midnight_sync = {
      schedule    = "cron(0 0 * * ? *)"      # Midnight daily
      task_count  = 3
      environment = "production"
    }
  }
}

module "data_sync_tasks" {
  for_each = local.data_sync_schedules
  source   = "../"

  ecs_cluster_name    = var.cluster_name
  name                = "data-sync-${each.key}"
  schedule_expression = each.value.schedule

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  task_count = each.value.task_count

  event_input = jsonencode({
    sync_type    = each.key
    environment  = each.value.environment
    parallel_jobs = each.value.task_count
  })

  tags = {
    Schedule    = each.key
    Environment = each.value.environment
    Purpose     = "DataSync"
  }
}

################################################################################
# Conditional Scheduling Based on Environment
################################################################################

module "conditional_scheduled_task" {
  source = "../"

  ecs_cluster_name = var.cluster_name
  name             = "conditional-processor"
  
  # Different schedules for different environments
  schedule_expression = var.environment == "production" ? "rate(5 minutes)" : var.environment == "staging" ? "rate(30 minutes)" : "rate(1 hour)"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Different resources based on environment
  task_count      = var.environment == "production" ? 3 : 1

  # Enable/disable based on environment
  state = var.environment == "development" ? "DISABLED" : "ENABLED"

  tags = {
    Environment = var.environment
    Conditional = "true"
  }
}

# Schedule Expression Reference:
# 
# Rate expressions:
# - rate(5 minutes)
# - rate(1 hour)
# - rate(7 days)
#
# Cron expressions: cron(Minutes Hours Day-of-month Month Day-of-week Year)
# - Minutes: 0-59
# - Hours: 0-23
# - Day-of-month: 1-31 (use L for last day)
# - Month: 1-12 or JAN-DEC
# - Day-of-week: 1-7 or SUN-SAT (use #n for nth occurrence)
# - Year: 1970-2199
#
# Special characters:
# - * (all values)
# - , (list separator)
# - - (range)
# - / (increments)
# - ? (any)
# - L (last)
# - W (weekday)
# - # (nth)
