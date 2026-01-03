
# Security Groups 

# Access control is based on Security Group IDs  for flexibility.

# Security Flow:
# API Gateway → Lambda (RVK-mongo-db-sg) → MongoDB (RVK-ecs-mongo-sg) → EFS (mongo-efs-sg)
#           27017                      

# 1. LAMBDA SECURITY GROUP (Application Tier - The Client)

resource "aws_security_group" "lambda_sg" {
  name        = "RVK-mongo-db-sg"
  description = "Security Group for Lambda API - Application Tier"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "RVK-mongo-db-sg"
    Tier        = "Application"
    Description = "Lambda API Security Group"
  }
}

# Egress Rule: Lambda → MongoDB on port 27017
resource "aws_security_group_rule" "lambda_to_mongodb" {
  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_sg.id
  source_security_group_id = aws_security_group.mongodb_sg.id
  description              = "Allow Lambda to connect to MongoDB on port 27017"
}

# Egress Rule: Lambda → Internet (HTTPS) for AWS API calls and npm packages
resource "aws_security_group_rule" "lambda_to_internet_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lambda_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow Lambda HTTPS access for AWS APIs and external services"
}

# Egress Rule: Lambda → Internet (HTTP) for pulling packages during builds****
resource "aws_security_group_rule" "lambda_to_internet_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.lambda_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow Lambda HTTP access for package downloads"
}


# 2. MONGODB SECURITY GROUP (Data Tier - The Database)


resource "aws_security_group" "mongodb_sg" {
  name        = "RVK-ecs-mongo-sg"
  description = "Security Group for MongoDB ECS Task - Data Tier"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "RVK-ecs-mongo-sg"
    Tier        = "Data"
    Description = "MongoDB ECS Security Group"
  }
}

# Ingress Rule: Lambda → MongoDB on port 27017
resource "aws_security_group_rule" "mongodb_from_lambda" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mongodb_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
  description              = "Allow Lambda to access MongoDB on port 27017"
}

# Egress Rule: MongoDB → EFS on port 2049 (NFS)
resource "aws_security_group_rule" "mongodb_to_efs" {
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mongodb_sg.id
  source_security_group_id = aws_security_group.efs_sg.id
  description              = "Allow MongoDB to mount EFS volume on port 2049 (NFS)"
}

# Egress Rule: MongoDB → Internet (HTTPS) for CloudWatch Logs, Docker pulls, and AWS APIs
resource "aws_security_group_rule" "mongodb_to_internet_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.mongodb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS for CloudWatch Logs, ECR/Docker Hub, and AWS API calls"
}

# Egress Rule: MongoDB → Internet (HTTP) for Docker image pulls
resource "aws_security_group_rule" "mongodb_to_internet_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.mongodb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP for Docker Hub image pulls"
}

# Egress Rule: MongoDB → DNS resolution
resource "aws_security_group_rule" "mongodb_to_dns" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.mongodb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow DNS resolution for MongoDB ECS"
}

# 3. EFS SECURITY GROUP (Storage Tier - Persistent Data)

resource "aws_security_group" "efs_sg" {
  name        = "mongo-efs-sg"
  description = "Security Group for EFS - Storage Tier"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "mongo-efs-sg"
    Tier        = "Storage"
    Description = "EFS Security Group for MongoDB Persistence"
  }
}

# Ingress Rule: MongoDB → EFS on port 2049 (NFS)
resource "aws_security_group_rule" "efs_from_mongodb" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs_sg.id
  source_security_group_id = aws_security_group.mongodb_sg.id
  description              = "Allow MongoDB ECS to mount EFS on port 2049 (NFS)"
}

