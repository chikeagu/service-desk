/*====
Variables used across all modules
======*/
locals {
  availability_zones = ["us-east-1a", "us-east-1b"]
}

provider "aws" {
  region  = "${var.region}"
}

resource "aws_key_pair" "key" {
  key_name   = "${var.key_name}"
  public_key = "${file("${var.key_name}.pem")}"
}

module "networking" {
  source               = "../modules/networking"
  environment          = "${var.environment}"
  vpc_cidr             = "10.0.0.0/16"
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
  region               = "${var.region}"
  availability_zones   = "${local.availability_zones}"
  key_name             = "${var.key_name}"
}

module "ecs" {
  source              = "../modules/ecs"
  environment         = "${var.environment}"
  vpc_id              = "${module.networking.vpc_id}"
  availability_zones  = "${local.availability_zones}"
  mysql_repo_name     = "mysql"
  osticket_repo_name  = "campbellsoftwaresolutions/osticket"
  subnets_ids         = ["${module.networking.private_subnets_id}"]
  public_subnet_ids   = ["${module.networking.public_subnets_id}"]
  security_groups_ids = [
    "${module.networking.security_groups_ids}"
  ]
  region              = "${var.region}"
  mysql_database      = "${var.mysql_database}"
  mysql_password      = "${var.mysql_password}"
  mysql_root_password = "${var.mysql_root_password}"
  mysql_user          = "${var.mysql_user}"
  mysql_host          = "${var.mysql_host}"
}

module "code_pipeline" {
  source                               = "../modules/code_pipeline"
  osticket_repo_url                    = "${module.ecs.osticket_repository_url}"
  mysql_repo_url                       = "${module.ecs.mysql_repository_url}"
  region                               = "${var.region}"
  ecs_service_name_mysql               = "${module.ecs.mysql_service_name}"
  ecs_service_name_osticket            = "${module.ecs.osticket_service_name}"
  ecs_cluster_name                     = "${module.ecs.cluster_name}"
  run_task_subnet_id                   = "${module.networking.private_subnets_id[0]}"
  run_task_security_group_ids = ["${module.networking.security_groups_ids}", "${module.ecs.security_group_id}"]
  environment                 = "${var.environment}"
}
