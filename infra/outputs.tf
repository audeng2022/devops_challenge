# @Austin Deng
#
# Output Application Load Balancer DNS Name to be used for testing
# Also outputs ecr repository name and name tag for input into Github variables in step 2

output "alb_dns_name" 
{
  value = aws_lb.app_alb.dns_name
}

output "ecr_repository_name"
{
  value = "${var.project_name}-repo"
}

output "ecr_name_tag"
{
  value = "${var.project_name}-ec2"
}
