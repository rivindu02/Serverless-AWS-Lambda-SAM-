resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# The Blueprint for the Container
resource "aws_ecs_task_definition" "mongo" {
  family                   = "mongo-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name      = "mongo"
      image     = "mongo:latest"
      essential = true
      portMappings = [
        {
          containerPort = 27017
          hostPort      = 27017
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "efs-storage"
          containerPath = "/data/db"
          readOnly      = false
        }
      ]
    }
  ])

  volume {
    name = "efs-storage"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.mongo_data.id
      root_directory = "/"
    }
  }
}

# The Running Service
resource "aws_ecs_service" "mongo" {
  name            = "mongo-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mongo.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.ecs_private_1.id, aws_subnet.ecs_private_2.id]
    security_groups = [aws_security_group.mongodb_sg.id]
    # Set to false - ECS will use NAT Gateway for internet access (pulling images)
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mongo.arn
  }
}