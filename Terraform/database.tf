# Terraform/database.terraform 

# EFS File System--------> use EBS
resource "aws_efs_file_system" "mongo_data" {
  creation_token = "mongo-data"
  encrypted      = true
  tags           = { Name = "${var.project_name}-efs" }
}

# EFS Mount Targets (Connects EFS to ECS private subnets)
resource "aws_efs_mount_target" "mount_1" {
  file_system_id  = aws_efs_file_system.mongo_data.id
  subnet_id       = aws_subnet.ecs_private_1.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "mount_2" {
  file_system_id  = aws_efs_file_system.mongo_data.id
  subnet_id       = aws_subnet.ecs_private_2.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Service Discovery (DNS: mongo.local)
resource "aws_service_discovery_private_dns_namespace" "local" {
  name = "local"
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "mongo" {
  name = "mongo"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
}