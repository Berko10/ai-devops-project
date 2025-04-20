# =========================
# OUTPUTS
# =========================
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.devops_cluster.name
}

output "alb_dns_name" {
  value = aws_lb.devops_alb.dns_name
}
