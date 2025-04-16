terraform {
  backend "s3" {
    bucket         = "ai-devops-project-tf-state"
    key            = "main/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ai-devops-project-locks"
  }
}
