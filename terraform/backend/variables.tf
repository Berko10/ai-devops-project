variable "aws_region" {
  description = "AWS Region"
  default = "us-east-1"
}

variable "dynamo_table_name" {
  description = "DynamoDB table for Terraform state locking"
  default = "terraform-locks"
}
