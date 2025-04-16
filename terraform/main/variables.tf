variable "aws_region" {
  description = "AWS Region"
  default = "us-east-1"
}

variable "ecs_cluster_name" {
  description = "ECS Cluster Name"
  default = "my-ecs-cluster"
}

variable "ecr_repo_name" {
  description = "ECR Repo Name"
  default = "my-ecr-repo"
}

variable "alb_name" {
  description = "ALB Name"
  default = "my-alb"
}

variable "tf_bucket_name" {
  description = "S3 bucket for Terraform state"
  default = "my-devops-tf-state-bucket"
}

variable "dynamo_table_name" {
  description = "DynamoDB table for Terraform state locking"
  default = "terraform-locks"
}

variable "tfstate_path" {
  description = "The path to tfstate file"
  default = "main/terraform.tfstate"
}

