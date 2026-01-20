# Main Terraform configuration file to create AWS infrastructure

# Set version and AWS as provider
terraform 
{
  required_version = ">= 1.5.0"
  required_providers 
  {
    aws = 
    {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" 
{
  region = var.aws_region
}

# Get AWS credentials to authenticate
data "aws_caller_identity" "current" {}

# Provision EC2 Instance

# Application Load Balancer

# Security Group port 80 restrics ssh

# IAM role
