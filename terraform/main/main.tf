###################################### 
# main.tf - Complete Infra Without Modules 
###################################### 

provider "aws" {
  region = var.aws_region
}

######################## 
# VPC and Networking 
######################## 

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "devops-vpc"
    Project = "DevOpsProject"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "public-subnet-a"
    Project = "DevOpsProject"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name    = "public-subnet-b"
    Project = "DevOpsProject"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "devops-igw"
    Project = "DevOpsProject"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "devops-public-rt"
    Project = "DevOpsProject"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

######################## 
# Security Group 
######################## 

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name    = "alb-sg"
    Project = "DevOpsProject"
  }
}

######################## 
# ALB + Target Group 
######################## 

resource "aws_lb" "devops_alb" {
  name                             = "devops-alb"
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.alb_sg.id]
  subnets                          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  # enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name    = "devops-alb"
    Project = "DevOpsProject"
  }
}

resource "aws_lb_target_group" "devops_target_group" {
  name        = "devops-target-group"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "devops-target-group"
    Project = "DevOpsProject"
  }
}

resource "aws_lb_listener" "devops_listener" {
  load_balancer_arn = aws_lb.devops_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.devops_target_group.arn
  }

  tags = {
    Name    = "devops-listener"
    Project = "DevOpsProject"
  }
}

######################## 
# ECS + ECR 
######################## 

resource "aws_ecs_cluster" "devops_cluster" {
  name = "devops-cluster"

  tags = {
    Name    = "devops-cluster"
    Project = "DevOpsProject"
  }
}

resource "aws_ecr_repository" "app_repo" {
  name                 = "devops-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  lifecycle {
    ignore_changes = [image_tag_mutability]
  }

  tags = {
    Name    = "devops-app"
    Project = "DevOpsProject"
  }
}

resource "aws_iam_role" "ecs_task_exec_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [ {
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "ecs-task-execution-role"
    Project = "DevOpsProject"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "devops-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn

  container_definitions = jsonencode([{
    name        = "devops-app",
    image       = "${aws_ecr_repository.app_repo.repository_url}:latest",
    essential   = true,
    portMappings = [ {
      containerPort = 5000,
      hostPort      = 5000
    }],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = "/ecs/devops-app",
        awslogs-region        = var.aws_region,
        awslogs-stream-prefix = "devops-app"
      }
    }
  }])
  depends_on = [
    aws_ecr_repository.app_repo,
    aws_iam_role.ecs_task_exec_role
  ]

  tags = {
    Name    = "devops-task-definition"
    Project = "DevOpsProject"
  }
}

resource "aws_ecs_service" "app" {
  name            = "devops-service"
  cluster         = aws_ecs_cluster.devops_cluster.id
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.app.arn

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    assign_public_ip = true
    security_groups = [aws_security_group.alb_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.devops_target_group.arn
    container_name   = aws_ecs_task_definition.app.family
    container_port   = 5000
  }

  depends_on = [
    aws_ecs_task_definition.app,
    aws_lb.devops_alb
  ]

  tags = {
    Name    = "devops-ecs-service"
    Project = "DevOpsProject"
  }
}

######################## 
# Auto Scaling for ECS 
######################## 

resource "aws_appautoscaling_target" "ecs_scaling_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.devops_cluster.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name    = "ecs-scaling-target"
    Project = "DevOpsProject"
  }
}

resource "aws_appautoscaling_policy" "cpu_scaling_policy" {
  name               = "cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 50.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

######################## 
# Terraform Backend 
######################## 

terraform {
  backend "s3" {
    bucket = "ai-devops-project-tf-state-12346"
    key    = "terraform/state/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
