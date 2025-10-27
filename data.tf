data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}
