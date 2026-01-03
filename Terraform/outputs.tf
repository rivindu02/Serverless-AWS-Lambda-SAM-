# Terraform/outputs.tf

# --- SSM Parameters for SAM/Lambda ---
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/school-mgmt/vpc/id"
  type  = "String"
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "lambda_private_subnets" {
  name  = "/school-mgmt/vpc/lambda-private-subnets"
  type  = "StringList"
  value = join(",", [aws_subnet.lambda_private_1.id, aws_subnet.lambda_private_2.id])
}

resource "aws_ssm_parameter" "ecs_private_subnets" {
  name  = "/school-mgmt/vpc/ecs-private-subnets"
  type  = "StringList"
  value = join(",", [aws_subnet.ecs_private_1.id, aws_subnet.ecs_private_2.id])
}

resource "aws_ssm_parameter" "mongo_sg_id" {
  name  = "/school-mgmt/db/mongo-sg-id"
  type  = "String"
  value = aws_security_group.mongodb_sg.id
}

resource "aws_ssm_parameter" "lambda_sg_id" {
  name  = "/school-mgmt/lambda-sg-id"
  type  = "String"
  value = aws_security_group.lambda_sg.id
}

# --- Network Infrastructure Outputs ---
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.gw.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.nat.id
}

output "nat_gateway_eip" {
  description = "NAT Gateway Elastic IP"
  value       = aws_eip.nat.public_ip
}

# --- Subnet Outputs ---
output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "lambda_private_subnet_1_id" {
  description = "Lambda Private Subnet 1 ID (AZ A)"
  value       = aws_subnet.lambda_private_1.id
}

output "lambda_private_subnet_2_id" {
  description = "Lambda Private Subnet 2 ID (AZ B)"
  value       = aws_subnet.lambda_private_2.id
}

output "lambda_private_subnet_ids" {
  description = "All Lambda Private Subnet IDs"
  value       = [aws_subnet.lambda_private_1.id, aws_subnet.lambda_private_2.id]
}

output "ecs_private_subnet_1_id" {
  description = "ECS/MongoDB Private Subnet 1 ID (AZ A)"
  value       = aws_subnet.ecs_private_1.id
}

output "ecs_private_subnet_2_id" {
  description = "ECS/MongoDB Private Subnet 2 ID (AZ B)"
  value       = aws_subnet.ecs_private_2.id
}

output "ecs_private_subnet_ids" {
  description = "All ECS/MongoDB Private Subnet IDs"
  value       = [aws_subnet.ecs_private_1.id, aws_subnet.ecs_private_2.id]
}

# Deprecated - kept for backwards compatibility
output "private_subnet_1_id" {
  description = "[DEPRECATED] Use lambda_private_subnet_1_id or ecs_private_subnet_1_id instead"
  value       = aws_subnet.lambda_private_1.id
}

output "private_subnet_2_id" {
  description = "[DEPRECATED] Use lambda_private_subnet_2_id or ecs_private_subnet_2_id instead"
  value       = aws_subnet.lambda_private_2.id
}

output "private_subnet_ids" {
  description = "[DEPRECATED] Use lambda_private_subnet_ids or ecs_private_subnet_ids instead"
  value       = [aws_subnet.lambda_private_1.id, aws_subnet.lambda_private_2.id]
}

# --- Route Table Outputs ---
output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.private_rt.id
}

# --- Security Group Outputs ---
output "lambda_security_group_id" {
  description = "Lambda Security Group ID"
  value       = aws_security_group.lambda_sg.id
}

output "mongodb_security_group_id" {
  description = "MongoDB ECS Security Group ID"
  value       = aws_security_group.mongodb_sg.id
}

output "efs_security_group_id" {
  description = "EFS Security Group ID"
  value       = aws_security_group.efs_sg.id
}

# --- Database/Storage Outputs ---
output "efs_file_system_id" {
  description = "EFS File System ID"
  value       = aws_efs_file_system.mongo_data.id
}

output "service_discovery_namespace" {
  description = "Service Discovery Namespace"
  value       = aws_service_discovery_private_dns_namespace.local.name
}

output "mongodb_dns_name" {
  description = "MongoDB internal DNS name"
  value       = "mongo.local:27017"
}

# --- Network Architecture Summary ---
output "network_architecture" {
  description = "Network Architecture Overview"
  value = <<-EOT
    ====== NETWORK ARCHITECTURE ======
    
    VPC: ${aws_vpc.main.cidr_block}
    Region: ${var.aws_region}
    
    PUBLIC TIER (Internet-facing):
    - Public Subnet: ${aws_subnet.public.cidr_block} (AZ: ${aws_subnet.public.availability_zone})
      └─ NAT Gateway for private subnet internet access
    
    APPLICATION TIER (Lambda):
    - Lambda Private Subnet 1: ${aws_subnet.lambda_private_1.cidr_block} (AZ: ${aws_subnet.lambda_private_1.availability_zone})
    - Lambda Private Subnet 2: ${aws_subnet.lambda_private_2.cidr_block} (AZ: ${aws_subnet.lambda_private_2.availability_zone})
      └─ Lambda functions communicate with MongoDB via security groups
    
    DATA TIER (MongoDB/ECS):
    - ECS Private Subnet 1: ${aws_subnet.ecs_private_1.cidr_block} (AZ: ${aws_subnet.ecs_private_1.availability_zone})
    - ECS Private Subnet 2: ${aws_subnet.ecs_private_2.cidr_block} (AZ: ${aws_subnet.ecs_private_2.availability_zone})
      └─ MongoDB ECS tasks with EFS storage
    
    NETWORK FLOW:
    Internet → API Gateway → Lambda (App Tier) → MongoDB (Data Tier) → EFS
    
    SECURITY:
    ✓ MongoDB isolated in dedicated private subnets
    ✓ Lambda isolated in separate private subnets
    ✓ No public IP assigned to MongoDB containers
    ✓ All outbound internet via NAT Gateway
    ✓ Security group rules enforce least-privilege access
    ==================================
  EOT
}