# Separate Variables file for reference in main.tf

variable "aws_region" 
{
  type    = string
  default = "us-east-1"
}

# Optional variable name to give resources created by Terraform, default is devops-challenge
variable "project_name" 
{
  type    = string
  default = "devops-challenge"
}

