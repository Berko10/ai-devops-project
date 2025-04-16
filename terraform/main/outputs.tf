output "alb_dns" {
  description = "Load balancer DNS"
  value       = module.alb.dns_name
}
output "ecr_repo_name" {
  value = aws_ecr_repository.app_repo.name
}