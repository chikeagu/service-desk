/*====
Variables used across all modules
======*/
locals {
  availability_zones = ["us-east-1a", "us-east-1b"]
}

provider "aws" {
  region  = "${var.region}"
}

module "networking" {
  source               = "../modules/networking"
  environment          = "${var.environment}"
  vpc_cidr             = "10.0.0.0/16"
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
  region               = "${var.region}"
  availability_zones   = "${local.availability_zones}"
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
