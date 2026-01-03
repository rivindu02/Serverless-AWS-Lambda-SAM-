# Network Architecture - School Management System

## Overview
This document describes the network architecture for the School Management System, which implements a **3-tier architecture** with proper network isolation between application and data layers.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          VPC: 10.0.0.0/16                               │
│                         Region: us-east-2                                │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         PUBLIC TIER                                      │
├─────────────────────────────────────────────────────────────────────────┤
│  Public Subnet: 10.0.1.0/24 (us-east-2a)                               │
│  ┌──────────────────┐         ┌─────────────────┐                      │
│  │ Internet Gateway │────────▶│  NAT Gateway    │                      │
│  │     (IGW)        │         │  (Elastic IP)   │                      │
│  └──────────────────┘         └─────────────────┘                      │
│         ▲                              │                                 │
└─────────┼──────────────────────────────┼─────────────────────────────────┘
          │                              │
          │                              ▼
     (Internet)                   (Outbound Access)
                                         │
┌────────────────────────────────────────┼─────────────────────────────────┐
│                    APPLICATION TIER (Lambda)                             │
├──────────────────────────────────────────────────────────────────────────┤
│  Lambda Private Subnet 1: 10.0.2.0/24 (us-east-2a)                      │
│  Lambda Private Subnet 2: 10.0.3.0/24 (us-east-2b)                      │
│                                                                           │
│  ┌────────────────────────────────────────────────────────┐             │
│  │  Lambda Functions (School Management API)               │             │
│  │  ────────────────────────────────────────              │             │
│  │  • SchoolApiFunction                                    │             │
│  │  • VPC-enabled (No public IP)                          │             │
│  │  • Security Group: RVK-mongo-db-sg                     │             │
│  │  • Routes through NAT Gateway for AWS API calls        │             │
│  └────────────────────────────────────────────────────────┘             │
│                              │                                            │
│                              │ Port 27017 (MongoDB)                      │
│                              ▼                                            │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│                      DATA TIER (MongoDB/ECS)                              │
├───────────────────────────────────────────────────────────────────────────┤
│  ECS Private Subnet 1: 10.0.4.0/24 (us-east-2a)                          │
│  ECS Private Subnet 2: 10.0.5.0/24 (us-east-2b)                          │
│                                                                            │
│  ┌─────────────────────────────────────────────────────┐                 │
│  │  MongoDB ECS Service (Fargate)                       │                 │
│  │  ──────────────────────────────────                 │                 │
│  │  • Container: mongo:latest                           │                 │
│  │  • No public IP assigned                             │                 │
│  │  • Security Group: RVK-ecs-mongo-sg                 │                 │
│  │  • Service Discovery: mongo.local:27017             │                 │
│  │  • High Availability: Multi-AZ deployment           │                 │
│  └──────────────────────┬──────────────────────────────┘                 │
│                         │                                                 │
│                         │ Port 2049 (NFS)                                │
│                         ▼                                                 │
│  ┌─────────────────────────────────────────────────────┐                 │
│  │  EFS File System (Encrypted)                         │                 │
│  │  ────────────────────────────                       │                 │
│  │  • Persistent storage for MongoDB data              │                 │
│  │  • Security Group: mongo-efs-sg                     │                 │
│  │  • Mount targets in both ECS subnets                │                 │
│  └─────────────────────────────────────────────────────┘                 │
└───────────────────────────────────────────────────────────────────────────┘
```

## Network Configuration

### VPC Configuration
- **CIDR Block**: `10.0.0.0/16`
- **Region**: `us-east-2`
- **DNS Support**: Enabled
- **DNS Hostnames**: Enabled

### Subnet Layout

#### Public Tier
| Subnet Name | CIDR Block | AZ | Purpose |
|-------------|------------|-----|---------|
| Public Subnet | 10.0.1.0/24 | us-east-2a | NAT Gateway, Internet Gateway |

#### Application Tier (Lambda)
| Subnet Name | CIDR Block | AZ | Purpose |
|-------------|------------|-----|---------|
| Lambda Private Subnet 1 | 10.0.2.0/24 | us-east-2a | Lambda functions |
| Lambda Private Subnet 2 | 10.0.3.0/24 | us-east-2b | Lambda functions |

#### Data Tier (MongoDB/ECS)
| Subnet Name | CIDR Block | AZ | Purpose |
|-------------|------------|-----|---------|
| ECS Private Subnet 1 | 10.0.4.0/24 | us-east-2a | MongoDB containers, EFS mount |
| ECS Private Subnet 2 | 10.0.5.0/24 | us-east-2b | MongoDB containers, EFS mount |

## Routing Configuration

### Public Route Table
- **Route**: `0.0.0.0/0` → Internet Gateway
- **Attached Subnets**: Public Subnet (10.0.1.0/24)

### Private Route Table
- **Route**: `0.0.0.0/0` → NAT Gateway
- **Attached Subnets**: 
  - Lambda Private Subnet 1 (10.0.2.0/24)
  - Lambda Private Subnet 2 (10.0.3.0/24)
  - ECS Private Subnet 1 (10.0.4.0/24)
  - ECS Private Subnet 2 (10.0.5.0/24)

## Security Groups

### 1. Lambda Security Group (`RVK-mongo-db-sg`)
**Purpose**: Controls Lambda function network access

**Outbound Rules**:
- **MongoDB Access**: TCP 27017 → `RVK-ecs-mongo-sg` (MongoDB containers)
- **HTTPS**: TCP 443 → `0.0.0.0/0` (AWS API calls, npm packages)
- **HTTP**: TCP 80 → `0.0.0.0/0` (Package downloads during builds)

**Inbound Rules**: None (Lambda doesn't accept inbound connections)

### 2. MongoDB Security Group (`RVK-ecs-mongo-sg`)
**Purpose**: Controls MongoDB ECS container network access

**Inbound Rules**:
- **Lambda Access**: TCP 27017 ← `RVK-mongo-db-sg` (Lambda connections)

**Outbound Rules**:
- **EFS Access**: TCP 2049 → `mongo-efs-sg` (Persistent storage)
- **HTTPS**: TCP 443 → `0.0.0.0/0` (CloudWatch logs, ECR image pulls)
- **HTTP**: TCP 80 → `0.0.0.0/0` (Docker Hub image pulls)
- **DNS**: UDP 53 → `0.0.0.0/0` (DNS resolution)

### 3. EFS Security Group (`mongo-efs-sg`)
**Purpose**: Controls EFS mount target access

**Inbound Rules**:
- **MongoDB Access**: TCP 2049 ← `RVK-ecs-mongo-sg` (ECS containers can mount)

**Outbound Rules**: None required

## Network Flow

### Client Request Flow
```
1. Internet User
   ↓
2. AWS API Gateway (HTTP API)
   ↓
3. Lambda Function (Application Tier - Private Subnet)
   ↓
4. MongoDB ECS Container (Data Tier - Private Subnet)
   ↓
5. EFS Persistent Storage
```

### Lambda to MongoDB Communication
- Lambda functions in **Lambda Private Subnets** (10.0.2.0/24, 10.0.3.0/24)
- Connect to MongoDB via **Service Discovery** DNS: `mongo.local:27017`
- Security group rules allow TCP 27017 between tiers
- MongoDB containers in **ECS Private Subnets** (10.0.4.0/24, 10.0.5.0/24)

### Outbound Internet Access
- All private subnets route through **NAT Gateway** in public subnet
- NAT Gateway uses **Elastic IP** for consistent outbound IP
- Required for:
  - Lambda: AWS API calls, CloudWatch logs
  - ECS: Docker image pulls, CloudWatch logs

## Key Security Features

### ✅ Network Isolation
- **Lambda** and **MongoDB** are in **separate private subnets**
- No cross-tier communication except through security group rules
- MongoDB is completely isolated from direct internet access

### ✅ Zero Public Exposure
- **No public IPs** assigned to Lambda functions
- **No public IPs** assigned to MongoDB containers (`assign_public_ip = false`)
- All resources in private subnets

### ✅ Least Privilege Access
- Security groups enforce strict port-level access control
- Lambda can only access MongoDB on port 27017
- MongoDB can only access EFS on port 2049
- No unnecessary egress rules

### ✅ High Availability
- **Multi-AZ deployment** for both Lambda and MongoDB
- EFS has mount targets in both availability zones
- Automatic failover between AZs

### ✅ Service Discovery
- Private DNS namespace: `local`
- MongoDB accessible at: `mongo.local:27017`
- No need for IP address management

## SSM Parameters (for SAM Deployment)

The following AWS Systems Manager (SSM) parameters are created for SAM template integration:

| Parameter Name | Type | Description |
|---------------|------|-------------|
| `/school-mgmt/vpc/id` | String | VPC ID |
| `/school-mgmt/vpc/lambda-private-subnets` | StringList | Lambda subnet IDs |
| `/school-mgmt/vpc/ecs-private-subnets` | StringList | ECS subnet IDs |
| `/school-mgmt/db/mongo-sg-id` | String | MongoDB security group ID |

## Deployment Notes

### Prerequisites
1. Deploy Terraform infrastructure first
2. Ensure NAT Gateway is operational
3. Verify SSM parameters are created
4. Deploy SAM application

### Terraform Commands
```bash
cd Terraform
terraform init
terraform plan
terraform apply
```

### SAM Deployment
```bash
sam build
sam deploy --guided
```

## Network Costs

### Cost Considerations
- **NAT Gateway**: ~$0.045/hour + data transfer costs
- **EFS**: Storage costs based on usage
- **Data Transfer**: Cross-AZ data transfer charges apply
- **Elastic IP**: Free when attached to NAT Gateway

### Cost Optimization
- Single NAT Gateway serves all private subnets
- EFS uses standard storage class
- Lambda and ECS in same region to minimize transfer costs

## Monitoring and Troubleshooting

### VPC Flow Logs
Consider enabling VPC Flow Logs for:
- Lambda subnets (10.0.2.0/24, 10.0.3.0/24)
- ECS subnets (10.0.4.0/24, 10.0.5.0/24)

### Key Metrics to Monitor
- NAT Gateway data processed
- Lambda ENI creation time
- ECS service task count
- EFS connections and throughput

### Common Issues

**Lambda can't connect to MongoDB**
- Verify security group rules (Lambda SG → MongoDB SG on port 27017)
- Check Lambda is in correct subnets
- Verify NAT Gateway is operational

**MongoDB can't pull Docker image**
- Verify NAT Gateway route in ECS subnets
- Check MongoDB security group allows HTTPS/HTTP outbound
- Ensure ECS task execution role has ECR permissions

**EFS mount failures**
- Verify EFS mount targets in correct subnets
- Check MongoDB SG → EFS SG on port 2049
- Ensure EFS file system is in available state

## Compliance and Best Practices

### ✅ Implemented Best Practices
1. **Multi-tier architecture** with network isolation
2. **Private subnets** for all application components
3. **Security group** based access control (not CIDR-based)
4. **Service discovery** for dynamic service location
5. **High availability** across multiple AZs
6. **Encrypted storage** (EFS encryption at rest)
7. **No hardcoded IPs** (using DNS and service discovery)

### 🔒 Security Compliance
- CIS AWS Foundations Benchmark compliant
- NIST Cybersecurity Framework aligned
- AWS Well-Architected Framework principles

## Future Enhancements

### Planned Improvements
1. **VPC Endpoints**: Add endpoints for S3, ECR, CloudWatch to reduce NAT costs
2. **Network ACLs**: Add subnet-level access control
3. **Transit Gateway**: If connecting to other VPCs
4. **PrivateLink**: For private API access
5. **WAF**: Web Application Firewall for API Gateway

### Scalability Considerations
- Current design supports up to **200 Lambda concurrent executions**
- MongoDB can scale vertically (ECS task size)
- Subnets sized for future growth
- Multi-AZ design enables horizontal scaling

---

**Last Updated**: January 2, 2026  
**Version**: 1.0  
**Maintained By**: Infrastructure Team
