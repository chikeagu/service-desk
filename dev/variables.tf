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

variable "key_name" {}

variable "bastion_ami" {
  default = {
    "us-east-1" = "ami-f652979b"
    "us-east-2" = "ami-fcc19b99"
    "us-west-1" = "ami-16efb076"
  }
}
