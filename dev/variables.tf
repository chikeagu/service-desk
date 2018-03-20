variable "environment" {
  description = "Environment to use e.g dev, prod"
  default = "dev"
}

variable "region" {
  description = "Region that the instances will be created"
}

variable "mysql_user" {}

variable "mysql_database" {}

variable "mysql_password" {}

variable "mysql_root_password" {}

variable "mysql_host" {}
