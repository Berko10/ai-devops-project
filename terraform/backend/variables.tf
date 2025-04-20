variable "aws_region" {
  description = "AWS Region"
  default = "us-east-1"
}

variable "dynamo_table_name" {
  description = "DynamoDB table for Terraform state locking"
  default = "terraform-locks"
}

variable "s3_bucket_name" {
  description = "S3 bucket for Terraform state file"
  default = "ai-devops-project-tf-state-12345"
}
