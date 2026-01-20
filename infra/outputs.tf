#Output Application Load Balancer DNS Name to be used for testing

output "alb_dns_name" 
{
  value = aws_lb.app_alb.dns_name
}
