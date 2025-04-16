variable "aws_region" {
  description = "AWS Region"
  default = "us-east-1"
}

variable "tf_bucket_name" {
  description = "S3 bucket for Terraform state"
  default = "my-devops-tf-state-bucket"
}

variable "dynamo_table_name" {
  description = "DynamoDB table for Terraform state locking"
  default = "terraform-locks"
}
