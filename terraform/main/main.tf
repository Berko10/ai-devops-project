provider "aws" {
  region = var.aws_region
}

# יצירת VPC בסיסי
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "devops-vpc"
  cidr = "10.0.0.0/16"

  azs       = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_dns_hostnames = true
  enable_nat_gateway   = false

  tags = {
    Project = "DevOpsProject"
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.0"

  cluster_name = "devops-cluster"
  vpc_id       = module.vpc.vpc_id
  subnets      = module.vpc.public_subnets

  tags = {
    Project = "DevOpsProject"
  }

  depends_on = [module.vpc]
}

# IAM Role for ECS task execution
resource "aws_iam_role" "ecs_task_exec_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Docker Image from ECR
resource "aws_ecr_repository" "app_repo" {
  name = "devops-app"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "devops-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn

  container_definitions = jsonencode([{
    name        = "devops-app"
    image       = "${aws_ecr_repository.app_repo.repository_url}:latest"
    essential   = true
    portMappings = [{
      containerPort = 5000
      hostPort      = 5000
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"     = "/ecs/devops-app"
        "awslogs-region"    = var.aws_region
        "awslogs-stream-prefix" = "devops-app"
      }
    }
  }])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "devops-service"
  cluster         = module.ecs.cluster_id
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.app.arn

  network_configuration {
    subnets         = module.vpc.public_subnets
    assign_public_ip = true
    security_groups = [aws_security_group.alb_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.devops_target_group.arn
    container_name   = "devops-app"
    container_port   = 5000
  }

  depends_on = [aws_lb.devops_alb]
}

# Auto Scaling for ECS Service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${module.ecs.cluster_id}/devops-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_scaling_policy" {
  name               = "ecs-scale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  target_tracking_scaling_policy_configuration {
    target_value       = 50.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
