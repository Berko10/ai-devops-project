output "alb_dns" {
  value = aws_lb.devops_alb.dns_name
}

output "ecr_repo_name" {
  value = aws_ecr_repository.app_repo.name
}