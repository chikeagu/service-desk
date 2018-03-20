/*====
Cloudwatch Log Group
======*/
resource "aws_cloudwatch_log_group" "service_desk" {
  name = "service_desk"

  tags {
    Environment = "${var.environment}"
    Application = "osticket"
  }
}

/*====
ECR repository to store our Docker images
======*/
resource "aws_ecr_repository" "osticket_app" {
  name = "${var.osticket_repo_name}"
}

resource "aws_ecr_repository" "mysql_app" {
  name = "${var.mysql_repo_name}"
}

/*====
ECS cluster
======*/
resource "aws_ecs_cluster" "cluster" {
  name = "${var.environment}-ecs-cluster"
}

/*====
ECS task definitions
======*/

/* osticket task definition service */
data "template_file" "osticket_task" {
  template = "${file("${path.module}/tasks/osticket_task_definition.json")}"

  vars {
    image           = "${aws_ecr_repository.osticket_app.repository_url}"
    log_group       = "${aws_cloudwatch_log_group.service_desk.name}"
    region          = "${var.region}"
    mysql_database  = "${var.mysql_database}"
    mysql_password  = "${var.mysql_password}"
    mysql_root_password = "${var.mysql_root_password}"
    mysql_user      = "${var.mysql_user}"
    mysql_host      = "${var.mysql_host}"
  }
}

resource "aws_ecs_task_definition" "osticket" {
  family                   = "${var.environment}_osticket"
  container_definitions    = "${data.template_file.osticket_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}

/* mysql task definition service */
data "template_file" "mysql_task" {
  template = "${file("${path.module}/tasks/mysql_task_definition.json")}"

  vars {
    image           = "${aws_ecr_repository.mysql_app.repository_url}"
    log_group       = "${aws_cloudwatch_log_group.service_desk.name}"
    region          = "${var.region}"
    mysql_database  = "${var.mysql_database}"
    mysql_password  = "${var.mysql_password}"
    mysql_root_password = "${var.mysql_root_password}"
    mysql_user      = "${var.mysql_user}"
  }
}

resource "aws_ecs_task_definition" "mysql" {
  family                   = "${var.environment}_mysql"
  container_definitions    = "${data.template_file.mysql_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}

/*====
App Load Balancer
======*/
resource "random_id" "target_group_sufix" {
  byte_length = 2
}

resource "aws_alb_target_group" "alb_target_group" {
  name     = "${var.environment}-alb-target-group-${random_id.target_group_sufix.hex}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

/* security group for ALB */
resource "aws_security_group" "osticket_inbound_sg" {
  name        = "${var.environment}-osticket-inbound-sg"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-osticket-inbound-sg"
  }
}

resource "aws_alb" "alb_service_desk" {
  name            = "${var.environment}-alb-service-desk"
  subnets         = ["${var.public_subnet_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.osticket_inbound_sg.id}"]

  tags {
    Name        = "${var.environment}-alb-service-desk"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "service_desk" {
  load_balancer_arn = "${aws_alb.alb_service_desk.arn}"
  port              = "80"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.alb_target_group"]

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}

/*
* IAM service role
*/
data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

/* ecs service scheduler role */
resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs_service_role_policy"
  #policy = "${file("${path.module}/policies/ecs-service-role.json")}"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role   = "${aws_iam_role.ecs_role.id}"
}

/* role that the Amazon ECS container agent and the Docker daemon can assume */
resource "aws_iam_role" "ecs_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-task-execution-role.json")}"
}
resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
  role   = "${aws_iam_role.ecs_execution_role.id}"
}

/*====
ECS service
======*/

/* Security Group for ECS */
resource "aws_security_group" "ecs_service" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

/* Simply specify the family to find the latest ACTIVE revision in that family */
data "aws_ecs_task_definition" "osticket" {
  depends_on = ["aws_ecs_task_definition.mysql"]
  task_definition = "${aws_ecs_task_definition.osticket.family}"
}

resource "aws_ecs_service" "osticket" {
  name            = "${var.environment}-osticket"
  task_definition = "${aws_ecs_task_definition.osticket.family}:${max("${aws_ecs_task_definition.osticket.revision}", "${data.aws_ecs_task_definition.osticket.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster =       "${aws_ecs_cluster.cluster.id}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name   = "osticket"
    container_port   = "80"
  }

  depends_on = ["aws_alb_target_group.alb_target_group"]
}

/* mysql service?? 
   We should have a way to say that osticket depends on mysql
   How do I specify the port for mysql i.e 3306??
*/
data "aws_ecs_task_definition" "mysql" {
  depends_on = ["aws_ecs_task_definition.mysql"]
  task_definition = "${aws_ecs_task_definition.mysql.family}"
}

resource "aws_ecs_service" "mysql" {
  name            = "${var.environment}-mysql"
  task_definition = "${aws_ecs_task_definition.mysql.family}:${max("${aws_ecs_task_definition.mysql.revision}", "${data.aws_ecs_task_definition.mysql.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  cluster =       "${aws_ecs_cluster.cluster.id}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }
}
