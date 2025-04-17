# alb.tf

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "devops_alb" {
  name               = "devops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "devops-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "devops_target_group" {
  name     = "devops-target-group"
  port     = 5000
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    path = "/"
    interval = 30
    timeout  = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  vpc_id = module.vpc.vpc_id
}

# ALB Listener
resource "aws_lb_listener" "devops_listener" {
  load_balancer_arn = aws_lb.devops_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.devops_target_group.arn
  }
}
