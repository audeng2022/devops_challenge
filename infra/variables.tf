# Separate Variables file for reference in main.tf

variable "aws_region" 
{
  type    = string
  default = "us-east-1"
}

# Optional variable name to give resources created by Terraform
variable "deployment_name" 
{
  type    = string
  default = "devops-challenge"
}

# Restrict SSH, so give option to enter your IP, otherwise default to "1.2.3.4/32"
variable "allowed_ssh_cidr" 
{
  type = string
  default = "1.2.3.4/32"
}
