# Terraform/main.terraform 


provider "aws" {
  region = var.aws_region
}

# 1. The VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  #
  enable_dns_support   = true
  ## What it does: It allows your VPC to resolve public DNS hostnames (like google.com) and internal AWS service endpoints.
  ## The "AmazonProvidedDNS" IP: When this is true, AWS reserves the .2 address of your VPC network range (e.g., if your VPC is 10.0.0.0/16, the resolver is at 10.0.0.2) to act as your DNS server.
  ## If you set it to false: Your instances will not be able to resolve any domain names unless you manually configure your own DNS server within the VPC.
  enable_dns_hostnames = true
  ## What it does: If an instance is launched in a public subnet and gets a public IP, AWS will also give it a readable hostname (e.g., ec2-54-12-34-56.compute-1.amazonaws.com).
  ## Internal Resolution: It also ensures that instances get a private DNS hostname (e.g., ip-10-0-1-24.ec2.internal).
  ## Prerequisite: This setting only works if enable_dns_support is also set to true.
  tags = { Name = "${var.project_name}-vpc" }
}

# 2. Internet Gateway (Required for ECS to pull images)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

# 3. Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.gw]
  tags = { Name = "${var.project_name}-nat-eip" }
}

# 4. NAT Gateway (Allows private subnets to access internet)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw]
  tags = { Name = "${var.project_name}-nat" }
}

# 5. Public Route Table (Routes traffic to Internet Gateway)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

# 6. Private Route Table (Routes traffic to NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

# 7. Public Subnet (For NAT Gateway, Bastion Hosts, Load Balancers)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet"
    Type = "Public"
  }
}

# 8. Lambda Private Subnet 1 (AZ A)
resource "aws_subnet" "lambda_private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.lambda_private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.project_name}-lambda-private-subnet-1"
    Type = "Private"
    Tier = "Application"
  }
}

# 9. Lambda Private Subnet 2 (AZ B)
resource "aws_subnet" "lambda_private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.lambda_private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "${var.project_name}-lambda-private-subnet-2"
    Type = "Private"
    Tier = "Application"
  }
}

# 10. ECS/MongoDB Private Subnet 1 (AZ A)
resource "aws_subnet" "ecs_private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.ecs_private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.project_name}-ecs-private-subnet-1"
    Type = "Private"
    Tier = "Data"
  }
}

# 11. ECS/MongoDB Private Subnet 2 (AZ B)
resource "aws_subnet" "ecs_private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.ecs_private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "${var.project_name}-ecs-private-subnet-2"
    Type = "Private"
    Tier = "Data"
  }
}

# 12. Route Table Associations

# Public subnet uses Internet Gateway for internet access
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Lambda private subnets use NAT Gateway for outbound internet access
resource "aws_route_table_association" "lambda_private_1_assoc" {
  subnet_id      = aws_subnet.lambda_private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "lambda_private_2_assoc" {
  subnet_id      = aws_subnet.lambda_private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# ECS/MongoDB private subnets use NAT Gateway for outbound internet access
resource "aws_route_table_association" "ecs_private_1_assoc" {
  subnet_id      = aws_subnet.ecs_private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "ecs_private_2_assoc" {
  subnet_id      = aws_subnet.ecs_private_2.id
  route_table_id = aws_route_table.private_rt.id
}