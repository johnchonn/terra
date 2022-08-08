terraform {
  required_version = "~> 1.1"
  backend "local" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.11"
    }
  }
}

provider "aws" {
  allowed_account_ids = local.allowed_accounts
  region              = "us-west-2"
  profile             = local.aws_admin_user
}

resource "aws_vpc" "MEOW_VPC" {
  cidr_block           = "10.0.0.0/20"
  enable_dns_hostnames = true
  tags                 = { Name = "MEOW_VPC" }
}

resource "aws_subnet" "MEOW_PUBLIC_SUBNET_A" {
  vpc_id            = aws_vpc.MEOW_VPC.id
  cidr_block        = "10.0.0.0/22"
  availability_zone = "us-west-2a"
  tags              = { Name = "MEOW_PUBLIC_SUBNET_A" }
}

resource "aws_subnet" "MEOW_PUBLIC_SUBNET_B" {
  vpc_id            = aws_vpc.MEOW_VPC.id
  cidr_block        = "10.0.4.0/22"
  availability_zone = "us-west-2b"
  tags              = { Name = "MEOW_PUBLIC_SUBNET_B" }
}

resource "aws_subnet" "MEOW_PRIVATE_SUBNET_A" {
  vpc_id            = aws_vpc.MEOW_VPC.id
  cidr_block        = "10.0.8.0/22"
  availability_zone = "us-west-2a"
  tags              = { Name = "MEOW_PRIVATE_SUBNET_A" }
}

resource "aws_subnet" "MEOW_PRIVATE_SUBNET_B" {
  vpc_id            = aws_vpc.MEOW_VPC.id
  cidr_block        = "10.0.12.0/22"
  availability_zone = "us-west-2b"
  tags              = { Name = "MEOW_PRIVATE_SUBNET_B" }
}

resource "aws_internet_gateway" "MEOW_INTERNET_GATEWAY" {
  vpc_id = aws_vpc.MEOW_VPC.id
  tags   = { Name = "MEOW_INTERNET_GATEWAY" }
}

resource "aws_default_route_table" "MEOW_DEFAULT_ROUTE_TABLE" {
  default_route_table_id = aws_vpc.MEOW_VPC.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MEOW_INTERNET_GATEWAY.id
  }
  tags = { Name = "MEOW_DEFAULT_ROUTE_TABLE" }
}

resource "aws_route_table" "MEOW_PRIVATE_ROUTE_TABLE" {
  vpc_id = aws_vpc.MEOW_VPC.id
  tags   = { Name = "MEOW_PRIVATE_ROUTE_TABLE" }
}

resource "aws_route_table_association" "MEOW_PRIVATE_ROUTE_TABLE_A_ASSOCIATION" {
  subnet_id      = aws_subnet.MEOW_PRIVATE_SUBNET_A.id
  route_table_id = aws_route_table.MEOW_PRIVATE_ROUTE_TABLE.id
}

resource "aws_route_table_association" "MEOW_PRIVATE_ROUTE_TABLE_B_ASSOCIATION" {
  subnet_id      = aws_subnet.MEOW_PRIVATE_SUBNET_B.id
  route_table_id = aws_route_table.MEOW_PRIVATE_ROUTE_TABLE.id
}

resource "aws_security_group" "MEOW_PUBLIC_SG" {
  vpc_id = aws_vpc.MEOW_VPC.id

  egress {
    description = "allow all outbound traffic"
    protocol    = "-1" # -1 means all protocols
    from_port   = 0    # 0 means all ports
    to_port     = 0    # 0 means all ports
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow inbound traffic from within SG"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  ingress {
    description = "allow inbound ssh traffic"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow inbound http traffic"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow inbound https traffic"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow inbound traffic on port 8080"
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "MEOW_PUBLIC_SG" }
}

data "aws_ami" "LATEST_UBUNTU_2004LTS_AMI" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "MEOW_PUBLIC_KEYPAIR" {
  key_name   = local.key_name
  public_key = local.key_public
}

resource "aws_launch_template" "MEOW_LAUNCH_TEMPLATE" {
  description   = "testing EC2 ASG"
  image_id      = "ami-0892d3c7ee96c0bf7"
  instance_type = "t3.small"
  key_name      = aws_key_pair.MEOW_PUBLIC_KEYPAIR.key_name
  name          = "meow-launch-template"

  update_default_version = true
  user_data = base64encode(templatefile(
    "${path.module}/init.sh",
    {
      psql_host = aws_db_instance.REMEMBER_POSTGRES_DATABASE.address
    }
  ))
  tags = { Name = "MEOW_LAUNCH_TEMPLATE" }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.MEOW_PUBLIC_SG.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "launched-with-meow-launch-template"
    }
  }
}

# Many parameters and configurable scenarios.
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "MEOW_AUTOSCALING_GROUP" {
  name = "meow-autoscaling-group"

  min_size = 1
  max_size = 5
  # I think this sets how many instances TF will wait for before exiting?
  desired_capacity = 3

  # Must be at least two, in at east two AZs.
  vpc_zone_identifier = [
    aws_subnet.MEOW_PUBLIC_SUBNET_A.id,
    aws_subnet.MEOW_PUBLIC_SUBNET_B.id,
  ]

  launch_template {
    id      = aws_launch_template.MEOW_LAUNCH_TEMPLATE.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [
      # Prevent TF from resetting desired capacity if we bump it manually from AWS console.
      desired_capacity,
      target_group_arns, # Suggested in the docs.
    ]
  }
}

# The set of resources that a load balancer sends traffic to.
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "MEOW_LB_TARGET_GROUP" {
  name_prefix = "meowlb" # 6 chars max :D
  port        = "8080"   # port on which *targets* receive traffic
  protocol    = "HTTP"
  vpc_id      = aws_vpc.MEOW_VPC.id

  lifecycle {
    # An LB listener must always have a target group. If we modify this we 
    # must create the new one before deleting the old one.
    create_before_destroy = true
  }
}

# Associates the LB's target group with the ASG.
resource "aws_autoscaling_attachment" "MEOW_AUTOSCALING_ATTACHMENT" {
  autoscaling_group_name = aws_autoscaling_group.MEOW_AUTOSCALING_GROUP.name
  lb_target_group_arn    = aws_lb_target_group.MEOW_LB_TARGET_GROUP.arn
}

# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "MEOW_LOAD_BALANCER" {
  name            = "meow-lb"
  internal        = false
  security_groups = [aws_security_group.MEOW_PUBLIC_SG.id]
  subnets = [
    aws_subnet.MEOW_PUBLIC_SUBNET_A.id,
    aws_subnet.MEOW_PUBLIC_SUBNET_B.id,
  ]
}

# Proxy for a load balancer: static routing, redirect, require auth, etc.
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
resource "aws_lb_listener" "MEOW_LB_LISTENER" {
  load_balancer_arn = aws_lb.MEOW_LOAD_BALANCER.arn
  port              = "80" # port on which the *LB* is listening
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.MEOW_LB_TARGET_GROUP.arn
  }
}