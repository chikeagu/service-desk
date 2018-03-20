output "osticket_repository_url" {
  value = "${aws_ecr_repository.osticket_app.repository_url}"
}

output "mysql_repository_url" {
  value = "${aws_ecr_repository.mysql_app.repository_url}"
}

output "cluster_name" {
  value = "${aws_ecs_cluster.cluster.name}"
}

output "osticket_service_name" {
  value = "${aws_ecs_service.osticket.name}"
}

output "mysql_service_name" {
  value = "${aws_ecs_service.mysql.name}"
}

output "alb_dns_name" {
  value = "${aws_alb.alb_service_desk.dns_name}"
}

output "alb_zone_id" {
  value = "${aws_alb.alb_service_desk.zone_id}"
}

output "security_group_id" {
  value = "${aws_security_group.ecs_service.id}"
}
