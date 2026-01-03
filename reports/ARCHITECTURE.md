# 🏗️ School Management System: AWS Hybrid Architecture

## Architecture Overview

This project implements a **Lambda-to-ECS-to-EFS architecture** providing a scalable, serverless API with a high-performance, persistent MongoDB database.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (Region: us-east-2)              │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                          │ │
│  │                                                               │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │              Public Subnet (10.0.1.0/24)                │ │ │
│  │  │                                                         │ │ │
│  │  │  ┌──────────────┐         ┌─────────────────┐         │ │ │
│  │  │  │   Internet   │◄────────┤   NAT Gateway   │         │ │ │
│  │  │  │   Gateway    │         │  (Elastic IP)   │         │ │ │
│  │  │  └──────┬───────┘         └────────▲────────┘         │ │ │
│  │  │         │                          │                   │ │ │
│  │  └─────────┼──────────────────────────┼───────────────────┘ │ │
│  │            │                          │                     │ │
│  │            │    ┌─────────────────────┘                     │ │
│  │            │    │                                           │ │
│  │  ┌─────────▼────┼─────────────────────────────────────────┐ │ │
│  │  │              │  Private Subnet 1 (10.0.2.0/24 - AZ A)  │ │ │
│  │  │              │                                          │ │ │
│  │  │  ┌───────────┴──────┐        ┌──────────────────┐     │ │ │
│  │  │  │  Lambda Function │◄───────┤  API Gateway /   │     │ │ │
│  │  │  │  (Express.js)    │        │  HTTP API        │     │ │ │
│  │  │  │  + JWT Auth      │        └──────────────────┘     │ │ │
│  │  │  └─────────┬────────┘                                 │ │ │
│  │  │            │                                           │ │ │
│  │  │            │ mongodb://mongo.local:27017              │ │ │
│  │  │            │ (Service Discovery)                      │ │ │
│  │  │            │                                           │ │ │
│  │  │  ┌─────────▼────────┐        ┌──────────────────┐    │ │ │
│  │  │  │   ECS Fargate    │◄───────┤   EFS Mount      │    │ │ │
│  │  │  │   (MongoDB)      │  NFS   │   Target         │    │ │ │
│  │  │  │   Port: 27017    │  2049  └────────┬─────────┘    │ │ │
│  │  │  └──────────────────┘                 │              │ │ │
│  │  │                                        │              │ │ │
│  │  └────────────────────────────────────────┼──────────────┘ │ │
│  │                                           │                │ │
│  │  ┌────────────────────────────────────────┼──────────────┐ │ │
│  │  │       Private Subnet 2 (10.0.3.0/24 - AZ B)          │ │ │
│  │  │                                        │              │ │ │
│  │  │                       ┌────────────────▼────────────┐ │ │ │
│  │  │                       │   EFS Mount Target          │ │ │
│  │  │                       │   (High Availability)       │ │ │
│  │  │                       └─────────────────────────────┘ │ │ │
│  │  │                                                       │ │ │
│  │  └───────────────────────────────────────────────────────┘ │ │
│  │                                                             │ │
│  │  ┌───────────────────────────────────────────────────────┐ │ │
│  │  │              Amazon EFS (Persistent Storage)          │ │ │
│  │  │              /data/db (MongoDB Data)                  │ │ │
│  │  │              Encrypted at Rest                        │ │ │
│  │  └───────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## 1. Networking Infrastructure (The Foundation)

### VPC Configuration
- **VPC CIDR**: `10.0.0.0/16`
- **DNS Support**: Enabled (allows resolution of public/private DNS)
- **DNS Hostnames**: Enabled (provides readable hostnames to instances)

### Internet Gateway (IGW)
- **Purpose**: Provides internet access for resources in public subnets
- **Usage**: Allows NAT Gateway to access the internet for outbound traffic from private subnets

### NAT Gateway
- **Location**: Public Subnet (10.0.1.0/24)
- **Purpose**: Allows resources in private subnets to access the internet for:
  - Pulling Docker images from ECR/Docker Hub
  - Installing npm packages
  - AWS service API calls
  - Outbound HTTPS traffic
- **Elastic IP**: Static public IP attached to NAT Gateway
- **Benefits**: 
  - Private resources remain unexposed
  - Managed service (no maintenance)
  - Highly available within AZ

### Subnets Architecture

#### Public Subnet (10.0.1.0/24) - AZ A
- **Route**: `0.0.0.0/0` → Internet Gateway
- **Purpose**: 
  - NAT Gateway placement
  - Future: Bastion hosts, Load Balancers, public-facing resources
- **Auto-assign Public IP**: Enabled

#### Private Subnet 1 (10.0.2.0/24) - AZ A
- **Route**: `0.0.0.0/0` → NAT Gateway
- **Purpose**: 
  - Lambda functions
  - ECS Fargate tasks (MongoDB)
  - EFS mount target
- **Auto-assign Public IP**: Disabled

#### Private Subnet 2 (10.0.3.0/24) - AZ B
- **Route**: `0.0.0.0/0` → NAT Gateway
- **Purpose**: 
  - High availability for Lambda
  - High availability for EFS
  - Cross-AZ redundancy
- **Auto-assign Public IP**: Disabled

### Service Discovery (AWS Cloud Map)
- **Namespace**: `local` (Private DNS)
- **Service**: `mongo`
- **DNS Name**: `mongo.local:27017`
- **TTL**: 60 seconds
- **Purpose**: Internal service discovery for Lambda to locate MongoDB

## 2. Database Layer (ECS Fargate + EFS)

### ECS Fargate Task
- **Image**: `mongo:latest` (Official MongoDB)
- **Launch Type**: Fargate (Serverless containers)
- **Network Mode**: `awsvpc`
- **CPU**: 512 units (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)
- **Port**: 27017 (MongoDB default)

### EFS Configuration
- **File System**: Encrypted at rest
- **Mount Path**: `/data/db` (MongoDB data directory)
- **Access Point**: 
  - UID/GID: 999 (MongoDB user)
  - Permissions: 755
  - Purpose: Proper ownership for MongoDB to write data
- **Mount Targets**: 
  - Private Subnet 1 (AZ A)
  - Private Subnet 2 (AZ B)
  - Provides high availability and cross-AZ access

### Data Persistence
- EFS ensures MongoDB data survives:
  - Task restarts
  - Task failures
  - ECS service updates
  - Manual redeployments

## 3. API Layer (AWS Lambda + Web Adapter)

### Lambda Function
- **Runtime**: Container (Docker)
- **Base Image**: `node:20-alpine`
- **Framework**: Express.js (Node.js)
- **Port**: 3000 (internal)
- **VPC Integration**: 
  - Private Subnets (1 & 2)
  - Lambda Security Group
  - Execution Role: `AWSLambdaVPCAccessExecutionRole`

### Lambda Web Adapter (LWA)
- **Binary**: `/opt/extensions/lambda-adapter`
- **Source**: `public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1`
- **Purpose**: 
  - Translates API Gateway events to HTTP requests
  - Routes requests to Express.js server
  - Handles response formatting
  - Enables standard web framework usage in Lambda

### Connection Caching
```javascript
// Cached connection for Lambda reuse
let cachedConnection = null;

export const connectToDatabase = async () => {
  if (mongoose.connection.readyState >= 1) {
    return mongoose.connection;
  }
  if (cachedConnection) {
    return cachedConnection;
  }
  cachedConnection = await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 5000,
    bufferCommands: false
  });
  return cachedConnection;
};
```

### Authentication
- **Strategy**: JWT (JSON Web Tokens)
- **Middleware**: 
  - `authenticate`: Verifies JWT token from Authorization header
  - `authorize`: Role-based access control (user/admin)
- **Protected Routes**: All API endpoints except `/auth/register` and `/auth/login`

## 4. Security Group "Handshake" (The Bridge)

### Traffic Flow (3-Tier Security Model)

#### 1. Lambda Security Group (`lambda_sg`)
```
Egress Rules:
├─ ALL Traffic (0.0.0.0/0) → Allow
└─ Purpose: Lambda can reach MongoDB, AWS APIs, Internet via NAT
```

#### 2. MongoDB ECS Security Group (`mongodb_sg`)
```
Ingress Rules:
├─ Port 27017 (TCP)
│  └─ Source: 10.0.0.0/16 (VPC CIDR)
│     └─ Purpose: Allow Lambda to connect to MongoDB

Egress Rules:
├─ ALL Traffic (0.0.0.0/0) → Allow
└─ Purpose: ECS can pull images, access EFS, reach AWS APIs
```

#### 3. EFS Security Group (`efs_sg`)
```
Ingress Rules:
├─ Port 2049 (TCP/NFS)
│  └─ Source: MongoDB SG
│     └─ Purpose: Allow ECS task to mount EFS volume
```

### Security Benefits
- **Private Subnets**: Database and API not directly exposed
- **Security Groups**: Stateful firewall rules
- **Least Privilege**: Only required ports/protocols allowed
- **VPC Isolation**: Resources isolated in private network
- **NAT Gateway**: Controlled outbound internet access
- **No Public IPs**: Private resources have no public IP addresses

## 5. Resource Communication Flow

### API Request Flow
```
User/Client
    │
    ▼
API Gateway (HTTP API)
    │
    ▼
Lambda Function (Private Subnet)
    │
    ├─ JWT Authentication
    ├─ Request Validation (Zod schemas)
    │
    ▼
MongoDB via Service Discovery (mongo.local:27017)
    │
    ▼
ECS Fargate (Private Subnet)
    │
    ▼
EFS (Persistent Storage)
    │
    ▼
Response back through chain
```

### Container Startup Flow
```
ECS Service initiates task
    │
    ▼
Pull Docker image
    │ (via NAT Gateway → Internet Gateway → Docker Hub)
    ▼
Launch container in Private Subnet
    │
    ▼
Mount EFS volume (via EFS Mount Target)
    │
    ▼
MongoDB starts and binds to port 27017
    │
    ▼
Register with Service Discovery (mongo.local)
    │
    ▼
Task Running (Health checks pass)
```

### Lambda Cold Start Flow
```
API Gateway invokes Lambda
    │
    ▼
Lambda ENI created in Private Subnet (Cold Start)
    │
    ▼
Connect to MongoDB via mongo.local:27017
    │
    ▼
Cache connection for subsequent invocations
    │
    ▼
Process request and return response
```

## 6. Cost Optimization

### Current Setup Costs (Estimated)
- **NAT Gateway**: ~$0.045/hour + data transfer (~$32/month)
- **EFS**: ~$0.30/GB-month (pay for what you use)
- **ECS Fargate**: ~$0.04/hour for 0.5 vCPU + 1GB RAM (~$29/month)
- **Lambda**: 
  - Free Tier: 1M requests/month, 400,000 GB-seconds
  - After free tier: $0.20 per 1M requests
- **API Gateway HTTP**: $1.00 per million requests
- **Elastic IP**: Free when attached to running NAT Gateway

### Total Monthly Cost (Low Traffic)
**~$70-80/month** (with NAT Gateway for proper architecture)

### Cost Reduction Strategies (Development)
1. **NAT Gateway**: 
   - For dev/testing: Consider VPC Endpoints for AWS services
   - Use NAT Instance (t4g.nano) - ~$3/month instead
   - Schedule NAT Gateway during working hours only
   
2. **ECS Fargate**: 
   - For dev: Use smallest task size
   - Consider Fargate Spot for non-production
   
3. **EFS**: 
   - Use EFS Lifecycle policies (transition to IA storage)
   - Provision only what you need

## 7. Deployment Steps

### Prerequisites
```bash
# Install required tools
aws configure
terraform --version
sam --version
```

### Step 1: Deploy Infrastructure
```bash
cd Terraform/
terraform init
terraform plan
terraform apply -auto-approve
```

### Step 2: Deploy Application
```bash
cd ..
sam build
sam deploy
```

### Step 3: Verify Deployment
```bash
# Check Lambda logs
sam logs -n SchoolApiFunction --stack-name school-management-sam --tail

# Test API endpoint
curl -X POST https://your-api-url/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","email":"admin@test.com","password":"admin123","role":"admin"}'
```

## 8. High Availability & Disaster Recovery

### Built-in HA Features
- **Multi-AZ Subnets**: Private subnets in 2 availability zones
- **EFS Multi-AZ**: Mount targets in both AZs
- **Lambda Multi-AZ**: Automatically deployed across AZs
- **NAT Gateway**: Single AZ (can be duplicated for HA)

### Disaster Recovery Strategy
- **EFS Backups**: Enable AWS Backup for EFS
- **MongoDB Backups**: 
  - EFS snapshots (manual or automated)
  - mongodump to S3 (scheduled Lambda function)
- **Infrastructure as Code**: Full Terraform state for recreation
- **RTO/RPO**: 
  - EFS restore: ~15 minutes
  - Full infrastructure rebuild: ~20 minutes

## 9. Monitoring & Observability

### CloudWatch Metrics
- Lambda invocations, errors, duration
- ECS task CPU/Memory utilization
- NAT Gateway connection count, data transfer
- API Gateway request count, latency

### CloudWatch Logs
- Lambda function logs
- ECS task logs (MongoDB logs)
- VPC Flow Logs (optional)

### Recommended Alarms
- Lambda errors > 5% threshold
- ECS task stopped unexpectedly
- NAT Gateway connection limit reached
- EFS burst credit balance low

## 10. Security Best Practices Implemented

✅ **Network Security**
- Private subnets for compute and database
- Security groups with least privilege
- No direct internet access to resources

✅ **Data Security**
- EFS encryption at rest
- JWT tokens for authentication
- Environment variables for secrets

✅ **Application Security**
- Input validation with Zod schemas
- Password hashing with bcryptjs
- Role-based access control

✅ **Infrastructure Security**
- IAM roles with minimal permissions
- VPC isolation
- CloudWatch logging enabled

## 11. Future Enhancements

### Phase 2 Improvements
- [ ] Add Application Load Balancer for custom domains
- [ ] Implement Redis/ElastiCache for session management
- [ ] Add RDS Read Replicas for scaling
- [ ] WAF rules for API protection
- [ ] Route53 for DNS management

### Phase 3 Improvements
- [ ] Multi-region deployment
- [ ] CloudFront CDN for global distribution
- [ ] DynamoDB for user sessions
- [ ] SQS for asynchronous processing
- [ ] Step Functions for complex workflows

---

## Quick Reference

| Component | Details |
|-----------|---------|
| **VPC CIDR** | 10.0.0.0/16 |
| **Public Subnet** | 10.0.1.0/24 (AZ A) |
| **Private Subnet 1** | 10.0.2.0/24 (AZ A) |
| **Private Subnet 2** | 10.0.3.0/24 (AZ B) |
| **MongoDB DNS** | mongo.local:27017 |
| **Lambda Timeout** | 30 seconds |
| **Lambda Memory** | 512 MB |
| **ECS CPU** | 0.5 vCPU |
| **ECS Memory** | 1 GB |
| **Region** | us-east-2 |

---

**Project**: School Management System  
**Architecture**: Lambda + ECS Fargate + EFS  
**Status**: Production Ready ✅
