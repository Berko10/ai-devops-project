provider "aws" {
  region = var.aws_region
}

# שימוש ב-VPC ברירת מחדל של ה-Playground
data "aws_vpc" "default" {
  default = true
}

# שימוש בסאבנטים פומביים ברירת מחדל של ה-Playground
data "aws_subnet_ids" "default_public" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  filter {
    name   = "availabilityZone"
    values = ["${var.aws_region}a", "${var.aws_region}b"] # התאם לפי האזורים הזמינים
  }
}

# שימוש ב-ECS Cluster קיים או יצירת אחד בסיסי
resource "aws_ecs_cluster" "main" {
  name = "playground-cluster" # שם קבוע וידוע ב-Playground?
  # אם קיים קלאסטר ברירת מחדל, ייתכן שלא יהיה צורך ליצור אחד חדש
  # אם יש בעיות הרשאות ביצירה, נסה להשתמש בשם ספציפי של קלאסטר ברירת מחדל אם ידוע
  tags = {
    Project = "DevOpsProjectPlayground"
  }
}

# IAM Role for ECS task execution - נשאר כפי שהוא
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
  role_       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Docker Image from ECR - נשאר כפי שהוא
resource "aws_ecr_repository" "app_repo" {
  name = "devops-app"
}

# ECS Task Definition - שימוש בקבוצת לוג קיימת או ברירת מחדל?
resource "aws_ecs_task_definition" "app" {
  family               = "devops-app"
  requires_compatibilities = ["FARGATE"]
  network_mode         = "awsvpc"
  cpu                  = "256"
  memory               = "512"
  execution_role_arn   = aws_iam_role.ecs_task_exec_role.arn

  container_definitions = jsonencode([{
    name      = "devops-app"
    image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 5000
      hostPort      = 5000
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"     = "/ecs/devops-app" # ייתכן שתצטרך קבוצה קיימת או שם ברירת מחדל
        "awslogs-region"    = var.aws_region
        "awslogs-stream-prefix" = "devops-app"
      }
    }
  }])
}

# ECS Service - שימוש ב-Security Group ברירת מחדל או יצירת אחד בסיסי
resource "aws_ecs_service" "app" {
  name            = "devops-service"
  cluster         = aws_ecs_cluster.main.id
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.app.arn

  network_configuration {
    subnets         = data.aws_subnet_ids.default_public.ids
    assign_public_ip = true
    security_groups = [aws_security_group.alb_sg.id] # נצטרך ליצור SG בסיסי אם אין הרשאה לשנות ברירת מחדל
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.devops_target_group.arn # נצטרך ליצור TG ו-ALB בסיסיים
    container_name   = "devops-app"
    container_port   = 5000
  }

  depends_on = [aws_ecs_cluster.main]
}

# Auto Scaling - ייתכן שנתקל בבעיות הרשאות, לכן כדאי להשבית זמנית
# resource "aws_appautoscaling_target" "ecs_target" {
#   max_capacity       = 4
#   min_capacity       = 1
#   resource_id        = "service/${module.ecs.cluster_id}/devops-service"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }
#
# resource "aws_appautoscaling_policy" "ecs_scaling_policy" {
#   name                 = "ecs-scale-policy"
#   policy_type          = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_target.resource_id
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
#   target_tracking_scaling_policy_configuration {
#     target_value       = 50.0
#     scale_in_cooldown  = 60
#     scale_out_cooldown = 60
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }
#   }
# }

# IAM Role for ALB Listener Permissions - ייתכן שנתקל בבעיות הרשאות, לכן כדאי להשבית זמנית
# resource "aws_iam_role" "alb_listener_role" {
#   name = "albListenerRole"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "ecs-tasks.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }
#
# # IAM Policy to allow ALB Listener and CloudWatch Log actions - ייתכן שנתקל בבעיות הרשאות
# resource "aws_iam_role_policy" "alb_listener_policy" {
#   name = "albListenerPolicy"
#   role = aws_iam_role.alb_listener_role.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "elasticloadbalancing:ModifyListenerAttributes",
#           "logs:PutRetentionPolicy"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# Application Load Balancer - ייתכן שנתקל בבעיות הרשאות, לכן ניצור אחד בסיסי
resource "aws_lb" "devops_alb" {
  name_prefix    = "devops-alb-"
  internal       = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets        = data.aws_subnet_ids.default_public.ids

  enable_deletion_protection = false # חשוב ל-Playground

  tags = {
    Project = "DevOpsProjectPlayground"
  }
}

# Target Group עבור ה-ALB
resource "aws_lb_target_group" "devops_target_group" {
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path     = "/" # התאם בהתאם לאפליקציה שלך
    protocol = "HTTP"
    matcher  = "200"
    interval = 30
    timeout  = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener עבור ה-ALB
resource "aws_lb_listener" "devops_listener" {
  load_balancer_arn = aws_lb.devops_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.devops_target_group.arn
  }
}

# Security Group עבור ה-ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg-"
  vpc_id      = data.aws_vpc.default.id

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
    Project = "DevOpsProjectPlayground"
  }
}
