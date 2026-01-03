# --- Project Metadata ---
variable "project_name" {
  description = "Name of the project used for tagging"
  type        = string
  default     = "rvk-school-mgmt"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

# --- Networking Variables ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "lambda_private_subnet_1_cidr" {
  description = "CIDR block for Lambda private subnet 1 (AZ A)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "lambda_private_subnet_2_cidr" {
  description = "CIDR block for Lambda private subnet 2 (AZ B)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "ecs_private_subnet_1_cidr" {
  description = "CIDR block for ECS/MongoDB private subnet 1 (AZ A)"
  type        = string
  default     = "10.0.4.0/24"
}

variable "ecs_private_subnet_2_cidr" {
  description = "CIDR block for ECS/MongoDB private subnet 2 (AZ B)"
  type        = string
  default     = "10.0.5.0/24"
}

# --- Database / ECS Variables ---
variable "mongo_port" {
  description = "The port MongoDB is listening on"
  type        = number
  default     = 27017
}

variable "cpu_units" {
  description = "Fargate CPU units (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "memory_limit" {
  description = "Fargate memory limit in MiB"
  type        = string
  default     = "512"
}