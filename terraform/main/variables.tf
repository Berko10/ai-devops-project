# ========================= 
# VARIABLES 
# ========================= 
variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "account_id" {
  description = "Your AWS Account ID"
  type        = string
  default = "076586969151"
}

variable "user_name" {
  description = "The IAM user name who will assume the role"
  type        = string
  deafault = "kk_labs_user_866577"
}
