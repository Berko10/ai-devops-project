output "alb_dns" {
  description = "Load balancer DNS"
  value       = module.alb.dns_name
}
