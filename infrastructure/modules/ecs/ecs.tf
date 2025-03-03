resource "aws_ecs_cluster" "ror_app_cluster" {
  name = var.ror_app_cluster_name
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = var.availability_zones[0]
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = var.availability_zones[1]
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = var.availability_zones[2]
}

resource "aws_ecs_task_definition" "ror_app_task" {
  family                   = var.ror_app_task_family
  container_definitions    = <<DEFINITION
    [
        {
            "name": "${var.ror_app_task_name}",
            "image": "${var.ecr_repo_url}",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": ${var.container_port1},
                    "hostPort": ${var.container_port1}
                }
            ],
            "memory": 512,
            "cpu": 256
        },
         {
            "name": "${var.ror_app_task_name1}",
            "image": "${var.ecr_repo_url1}",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": ${var.container_port},
                    "hostPort": ${var.container_port}
                }
            ],
            "memory": 2048,
            "cpu": 1024
        },
         {
            "name": "${var.ror_app_task_name2}",
            "image": "${var.ecr_repo_url2}",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": ${var.container_port2},
                    "hostPort": ${var.container_port2}
                }
            ],
            "memory": 512,
            "cpu": 256,
            "links": ["rails_app"]
        },
         {
            "name": "${var.ror_app_task_name3}",
            "image": "${var.ecr_repo_url3}",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": ${var.container_port},
                    "hostPort": ${var.container_port}
                }
            ],
            "memory": 512,
            "cpu": 256,
            "environment": [
                {
                    "name": "RDS_DB_NAME",
                    "value": "rails"
                },
                {
                    "name": "RDS_USERNAME",
                    "value": "postgres"
                },
                {
                    "name": "RDS_PASSWORD",
                    "value": "mypassword"
                },
                {
                    "name": "RDS_HOSTNAME",
                    "value": "postgres"
                },
                {
                    "name": "RDS_PORT",
                    "value": "5433"
                },
                {
                    "name": "S3_BUCKET_NAME",
                    "value": "s3-ror"
                },
                {
                    "name": "S3_REGION_NAME",
                    "value": "eu-central-1"
                },
                {
                    "name": "LB_ENDPOINT",
                    "value": "cc-ror-alb-tg:3000"
                }
            ]
        }
    ]
    DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 4096
  cpu                      = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = var.ecs_task_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_alb" "application_load_balancer" {
  name               = "cc-ror-app-alb"
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

resource "aws_security_group" "load_balancer_security_group" {
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

resource "aws_lb_target_group" "target_group" {
  name        = "cc-ror-alb-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_ecs_service" "ror_app_service" {
  name            = "cc-ror-app-service"
  cluster         = aws_ecs_cluster.ror_app_cluster.id
  task_definition = aws_ecs_task_definition.ror_app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = aws_ecs_task_definition.ror_app_task.family
    container_port   = var.container_port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.service_security_group.id}"]
  }
}

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
