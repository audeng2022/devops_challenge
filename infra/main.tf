# Main Terraform configuration file to create AWS infrastructure
# @Austin Deng

# Set version and AWS as cloud provider for Terraform
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

# Get AWS credentials to authenticate by looking up who is logged to AWS
data "aws_caller_identity" "current" {}





# ECR Repository where Github Actions will push image, name is devops-challenge-repo to be used later
resource "aws_ecr_repository" "app" 
{
  name = "${var.project_name}-repo"
}




#Sets default VPC and subnets for the region to keep things simpler
data "aws_vpc" "default" 
{
  default = true
}

data "aws_subnets" "default" 
{
  filter 
  {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}



# Application Load Balancer resources including ALB, the target group, and listener
# ALB using ALB firewall and default subnets
resource "aws_lb" "app_alb" 
{
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

# Target group where ALB sends traffic, ALB connects to instance on port 80
resource "aws_lb_target_group" "app_tg" 
{
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  # Checks info to ensure instance is healthy by getting HTTP 200
  health_check 
  {
    path                = "/info"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Attaches EC2 instance to target group
resource "aws_lb_target_group_attachment" "app_attach" 
{
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = 80
}

# Listener that forwards traffic to the target group when ALB is reached on port 80
resource "aws_lb_listener" "http" 
{
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action 
  {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}



# Security Group: allows everything to reach ALB at port 80
# Restricts SSH access to 1.2.3.4/32
# Port on EC2 instance is only accessible to ALB

resource "aws_security_group" "alb_sg" 
{
  name   = "${var.project_name}-alb-sg"
  vpc_id = data.aws_vpc.default.id

  # Allows TCP port 80 from the whole internet
  ingress 
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allows all outbound traffic
  egress 
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Security Group to restrict SSH
# SSH only allowed from 1.2.3.4/32 & Port 80 only from ALB SG
resource "aws_security_group" "ec2_sg" 
  {
  name   = "${var.project_name}-ec2-sg"
  vpc_id = data.aws_vpc.default.id

  # Restrict SSH to single IP
  ingress 
  {
    description = "Restrict SSH to single IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.2.3.4/32"]
  }

  # HTTP only allowed from ALB
  ingress 
  {
    description     = "HTTP only from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow all outbound traffic
  egress 
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}







# IAM roles for EC2, this allows EC2 to pull images without storing keys
# SSM is also attached to the IAM role to allow for registering with Systems Manager for deployment without using SSH 

# Creates policy that allows EC2 to use role
data "aws_iam_policy_document" "ec2_assume_role" 
{
  statement 
  {
    actions = ["sts:AssumeRole"]
    principals 
    {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  } 
}

# Creates the IAM role that the EC2 instance will use
resource "aws_iam_role" "ec2_role" 
{
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Adds AWS-managed policy for read-only ECR authentication and ability to pull images
# This satisfies the IAM role with minimal permissions in the requirements
resource "aws_iam_role_policy_attachment" "ecr_readonly" 
{
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Sets up instance profile IAM role for EC2
resource "aws_iam_instance_profile" "ec2_profile" 
{
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Attaches SSM to the role to register instance with Systems Manager, allows for deployment in Part 2 without using SSH
resource "aws_iam_role_policy_attachment" "ssm_core" 
{
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}






# Amazon Linux 2 AMI finds recent AMI for EC2 instance to use
data "aws_ami" "amazon_linux_2" 
{
  most_recent = true
  owners = ["amazon"]
  filter 
  {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Provision EC2 Instance using the AMI using t3.micro instance type
# Uses previous VPC, security groups, subnets, and instance profile
resource "aws_instance" "app" 
{
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  metadata_options 
  {
    http_tokens = "optional"
  }

  # User data is taken from user_data.sh.tftpl as template to ensure Docker container runs on boot
  user_data = templatefile("${path.module}/user_data.sh.tftpl", 
  {
    aws_region    = var.aws_region
    ecr_repo_url  = aws_ecr_repository.app.repository_url
    ecr_registry  = split("/", aws_ecr_repository.app.repository_url)[0]
  })

  # Tags will be important to identify instance in CI/CD pipeline
  tags = 
  {
    Name = "${var.project_name}-ec2"
  }
}
