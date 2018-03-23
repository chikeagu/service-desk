variable "region" {
  description = "The region to use"
}

variable "ecs_cluster_name" {
  description = "The cluster that we will deploy"
}

variable "ecs_service_name_mysql" {
  description = "The ECS service that will be deployed"
}

variable "ecs_service_name_osticket" {
  description = "The ECS service that will be deployed"
}

variable "run_task_subnet_id" {
  description = "The subnet Id where single run task will be executed"
}

variable "run_task_security_group_ids" {
  type        = "list"
  description = "The security group Ids attached where the single run task will be executed"
}

variable "environment" {}

variable "osticket_repo_url" {}

variable "mysql_repo_url" {}

variable "key_name" {}
