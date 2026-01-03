# 🏫 School Management API - Serverless AWS Lambda SAM

A production-grade, containerized **Express.js REST API** deployed on **AWS Lambda** using **AWS SAM** (Serverless Application Model). This project demonstrates a professional hybrid-cloud architecture utilizing **Terraform** for infrastructure and **AWS Lambda Web Adapter** to run a standard Node.js application in a serverless environment.

[![AWS](https://img.shields.io/badge/AWS-Lambda-orange?logo=amazon-aws)](https://aws.amazon.com/lambda/)
[![SAM](https://img.shields.io/badge/AWS-SAM-green?logo=amazon-aws)](https://aws.amazon.com/serverless/sam/)
[![Terraform](https://img.shields.io/badge/Terraform-v1.0+-purple?logo=terraform)](https://www.terraform.io/)
[![Node.js](https://img.shields.io/badge/Node.js-20-green?logo=node.js)](https://nodejs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-blue?logo=typescript)](https://www.typescriptlang.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Latest-green?logo=mongodb)](https://www.mongodb.com/)
[![Express.js](https://img.shields.io/badge/Express.js-5.x-black?logo=express)](https://expressjs.com/)

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Local Development](#-local-development)
- [Deployment](#-deployment)
- [API Documentation](#-api-documentation)
- [Infrastructure](#-infrastructure)
- [Security](#-security)
- [Contributing](#-contributing)

---

## ✨ Features

### Application Features
- 🔐 **JWT Authentication** - Secure user registration and login
- 👥 **Role-Based Access Control** - Admin and user roles
- 📚 **CRUD Operations** - Students, Teachers, and Courses management
- 📝 **Request Validation** - Zod schema validation
- 📖 **API Documentation** - Swagger/OpenAPI 3.0
- 🏥 **Health Checks** - Built-in health endpoints

### Infrastructure Features
- ⚡ **Serverless** - AWS Lambda with container image support
- 🐳 **Containerized** - Docker multi-stage builds
- 🔄 **Auto-scaling** - Lambda handles scaling automatically
- 💾 **Persistent Storage** - MongoDB on ECS Fargate with EFS
- 🔒 **Network Isolation** - 3-tier architecture with private subnets
- 🌐 **Service Discovery** - AWS Cloud Map for internal DNS

---

## 🏗 Architecture

```
                                    ┌─────────────────────────────────────┐
                                    │          AWS Cloud (us-east-2)      │
                                    │                                     │
┌────────────┐                      │  ┌─────────────────────────────────┐│
│            │  HTTPS               │  │         VPC: 10.0.0.0/16        ││
│   Client   │─────────────────────►│  │                                 ││
│            │                      │  │  ┌────────────┐                 ││
└────────────┘                      │  │  │ API Gateway│                 ││
                                    │  │  │ (HTTP API) │                 ││
                                    │  │  └─────┬──────┘                 ││
                                    │  │        │                        ││
                                    │  │        ▼                        ││
                                    │  │  ┌─────────────────────────┐    ││
                                    │  │  │     Lambda Function     │    ││
                                    │  │  │  ┌───────────────────┐  │    ││
                                    │  │  │  │ Lambda Web Adapter│  │    ││
                                    │  │  │  │    (Port 3000)    │  │    ││
                                    │  │  │  └─────────┬─────────┘  │    ││
                                    │  │  │            │            │    ││
                                    │  │  │  ┌─────────▼─────────┐  │    ││
                                    │  │  │  │   Express.js API  │  │    ││
                                    │  │  │  │  + JWT + Mongoose │  │    ││
                                    │  │  │  └───────────────────┘  │    ││
                                    │  │  └────────────┬────────────┘    ││
                                    │  │               │                 ││
                                    │  │               │ mongodb://      ││
                                    │  │               │ mongo.local:27017│
                                    │  │               ▼                 ││
                                    │  │  ┌─────────────────────────┐    ││
                                    │  │  │  MongoDB (ECS Fargate)  │    ││
                                    │  │  │  + Service Discovery    │    ││
                                    │  │  └────────────┬────────────┘    ││
                                    │  │               │                 ││
                                    │  │               ▼                 ││
                                    │  │  ┌─────────────────────────┐    ││
                                    │  │  │   Amazon EFS Storage    │    ││
                                    │  │  │   (Persistent Data)     │    ││
                                    │  │  └─────────────────────────┘    ││
                                    │  └─────────────────────────────────┘│
                                    └─────────────────────────────────────┘
```

### Network Layout

| Tier | Subnet | CIDR | Purpose |
|------|--------|------|---------|
| **Public** | public | 10.0.1.0/24 | NAT Gateway, Internet Gateway |
| **Application** | lambda_private_1 | 10.0.2.0/24 | Lambda functions (AZ-A) |
| **Application** | lambda_private_2 | 10.0.3.0/24 | Lambda functions (AZ-B) |
| **Data** | ecs_private_1 | 10.0.4.0/24 | MongoDB ECS (AZ-A) |
| **Data** | ecs_private_2 | 10.0.5.0/24 | MongoDB ECS (AZ-B) |

---

## 🛠 Tech Stack

### Backend
| Technology | Version | Purpose |
|------------|---------|---------|
| Node.js | 20 (Alpine) | Runtime environment |
| Express.js | 5.x | Web framework |
| TypeScript | 5.x | Type-safe development |
| Mongoose | 9.x | MongoDB ODM |
| Zod | 3.x | Schema validation |
| JWT | - | Authentication |
| bcrypt.js | - | Password hashing |

### Infrastructure
| Technology | Purpose |
|------------|---------|
| AWS Lambda | Serverless compute |
| AWS SAM | Serverless deployment |
| Terraform | Infrastructure as Code |
| ECS Fargate | MongoDB container hosting |
| Amazon EFS | Persistent storage |
| API Gateway | HTTP API endpoint |
| AWS Cloud Map | Service discovery |
| ECR | Container registry |

---

## 📁 Project Structure

```
├── 📂 app/                        # Express.js Application
│   ├── 🐳 Dockerfile              # Multi-stage Docker build
│   ├── 📦 package.json            # Dependencies
│   ├── ⚙️  tsconfig.json           # TypeScript config
│   └── 📂 src/
│       ├── 🚀 app.ts              # Express app initialization
│       ├── 🔌 server.ts           # HTTP server entry point
│       ├── 📂 config/
│       │   └── swagger.ts         # OpenAPI specification
│       ├── 📂 controllers/        # Request handlers
│       │   ├── authController.ts
│       │   ├── courseController.ts
│       │   ├── studentController.ts
│       │   └── teacherController.ts
│       ├── 📂 middleware/         # Express middleware
│       │   ├── auth.ts            # JWT authentication
│       │   └── validate.ts        # Zod validation
│       ├── 📂 models/             # Mongoose schemas
│       │   ├── User.ts
│       │   ├── Student.ts
│       │   ├── Course.ts
│       │   └── Teacher.ts
│       ├── 📂 routes/             # API routes
│       │   ├── authRoutes.ts
│       │   ├── courseRoutes.ts
│       │   ├── studentRoutes.ts
│       │   └── teacherRoutes.ts
│       ├── 📂 schemas/            # Zod validation schemas
│       ├── 📂 services/           # Business logic
│       └── 📂 utils/              # Utility functions
│
├── 📂 Terraform/                  # Infrastructure as Code
│   ├── main.tf                    # VPC, subnets, routing
│   ├── ecs.tf                     # ECS cluster & service
│   ├── database.tf                # EFS, service discovery
│   ├── security.tf                # Security groups
│   ├── variables.tf               # Input variables
│   └── outputs.tf                 # SSM parameters
│
├── 📂 reports/                    # Documentation
│   ├── ARCHITECTURE.md            # Architecture details
│   ├── NETWORK_ARCHITECTURE.md    # Network configuration
│   ├── SECURITY_GROUPS.md         # Security rules
│   └── CHANGES_SUMMARY.md         # Change history
│
├── 📄 template.yaml               # AWS SAM template
├── 📄 samconfig.toml              # SAM CLI configuration
└── 📄 README.md                   # This file
```

---

## 📋 Prerequisites

- **AWS CLI** v2.x configured with credentials
- **AWS SAM CLI** v1.x
- **Terraform** v1.0+
- **Docker** v20.x+
- **Node.js** v20.x
- **npm** v9.x+

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Serverless-AWS-Lambda-SAM-.git
cd Serverless-AWS-Lambda-SAM-
```

### 2. Deploy Infrastructure (Terraform)

```bash
cd Terraform

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Deploy infrastructure
terraform apply
```

### 3. Deploy Application (SAM)

```bash
# Return to root directory
cd ..

# Build the SAM application
sam build

# Deploy to AWS
sam deploy --guided
```

---

## 💻 Local Development

### Running Locally with Docker

```bash
cd app

# Start with Docker Compose
npm run docker:up

# Stop containers
npm run docker:down
```

### Running Without Docker

```bash
cd app

# Install dependencies
npm install

# Start development server
npm run dev
```

The API will be available at `http://localhost:3000`

### Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Compile TypeScript to JavaScript |
| `npm start` | Start production server |
| `npm test` | Run test suite |
| `npm run docker:up` | Start Docker containers |
| `npm run docker:down` | Stop Docker containers |

---

## 📦 Deployment

### Infrastructure Deployment Order

```
1. Terraform (Infrastructure)
   ├── VPC & Networking
   ├── Security Groups
   ├── ECS Cluster & MongoDB
   ├── EFS Storage
   └── SSM Parameters

2. SAM (Application)
   ├── Docker Build
   ├── Push to ECR
   ├── Lambda Function
   └── API Gateway
```

### Deploy Infrastructure

```bash
cd Terraform
terraform init
terraform apply
```

### Deploy Application

```bash
# Build Docker image and Lambda
sam build

# Deploy with confirmation prompts
sam deploy --guided

# Or deploy automatically
sam deploy
```

### Configuration (samconfig.toml)

```toml
[default.global.parameters]
stack_name = "school-management-sam"
region = "us-east-2"

[default.deploy.parameters]
capabilities = "CAPABILITY_IAM"
image_repository = "your-account.dkr.ecr.us-east-2.amazonaws.com/school-api"
```

---

## 📚 API Documentation

### Base URL
- **Local**: `http://localhost:3000`
- **Production**: `https://your-api-id.execute-api.us-east-2.amazonaws.com`

### Swagger UI
Access interactive documentation at `/api-docs`

### API Endpoints

#### Authentication
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/auth/register` | Register new user | No |
| POST | `/auth/login` | User login | No |
| GET | `/auth/profile` | Get user profile | Yes |

#### Students
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/students` | List all students | Yes |
| GET | `/students/:id` | Get student by ID | Yes |
| POST | `/students` | Create student | Admin |
| PUT | `/students/:id` | Update student | Admin |
| DELETE | `/students/:id` | Delete student | Admin |
| POST | `/students/:id/enroll` | Enroll in course | Admin |
| POST | `/students/:id/unenroll` | Remove from course | Admin |

#### Teachers
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/teachers` | List all teachers | Yes |
| GET | `/teachers/:id` | Get teacher by ID | Yes |
| POST | `/teachers` | Create teacher | Admin |
| PUT | `/teachers/:id` | Update teacher | Admin |
| DELETE | `/teachers/:id` | Delete teacher | Admin |

#### Courses
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/courses` | List all courses | Yes |
| GET | `/courses/:id` | Get course by ID | Yes |
| POST | `/courses` | Create course | Admin |
| PUT | `/courses/:id` | Update course | Admin |
| DELETE | `/courses/:id` | Delete course | Admin |

### Authentication

Include JWT token in Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

### Example Requests

**Register User**
```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "email": "admin@example.com",
    "password": "password123",
    "role": "admin"
  }'
```

**Login**
```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "password123"
  }'
```

**Create Course (Admin)**
```bash
curl -X POST http://localhost:3000/courses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "title": "Advanced Mathematics",
    "code": "MATH301",
    "credits": 3
  }'
```

---

## 🏢 Infrastructure

### Terraform Resources

| Resource | Description |
|----------|-------------|
| `aws_vpc.main` | Main VPC (10.0.0.0/16) |
| `aws_subnet.*` | Public and private subnets |
| `aws_nat_gateway.nat` | NAT Gateway for private subnet internet access |
| `aws_ecs_cluster.main` | ECS Fargate cluster |
| `aws_ecs_service.mongo` | MongoDB ECS service |
| `aws_efs_file_system.mongo_data` | Persistent storage |
| `aws_security_group.*` | Security groups for each tier |
| `aws_ssm_parameter.*` | SSM parameters for SAM |

### Terraform Commands

```bash
cd Terraform

# Initialize
terraform init

# Plan changes
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy

# View outputs
terraform output
```

---

## 🔐 Security

### Network Security
- ✅ **Private subnets** for Lambda and MongoDB
- ✅ **No public IPs** on database containers
- ✅ **NAT Gateway** for controlled outbound access
- ✅ **Security group references** instead of IP-based rules

### Application Security
- ✅ **JWT Authentication** with 7-day token expiry
- ✅ **bcrypt** password hashing with salt
- ✅ **Role-based access control** (user/admin)
- ✅ **Zod validation** for all inputs
- ✅ **CORS** configuration

### Security Groups

| Security Group | Tier | Inbound | Outbound |
|----------------|------|---------|----------|
| RVK-mongo-db-sg | Application | None | MongoDB:27017, Internet |
| RVK-ecs-mongo-sg | Data | Lambda:27017 | EFS:2049, Internet |
| mongo-efs-sg | Storage | MongoDB:2049 | None |

---

## 📊 Performance

| Metric | Value |
|--------|-------|
| Lambda Memory | 512 MB |
| Lambda Timeout | 30 seconds |
| Cold Start | ~2-3 seconds |
| Warm Start | ~100-200ms |
| ECS CPU | 256 units (0.25 vCPU) |
| ECS Memory | 512 MB |

---

## 📖 Documentation

For detailed architecture documentation, see [reports/ARCHITECTURE.md](reports/ARCHITECTURE.md).

---

## 🗺 Roadmap

- [ ] Add unit and integration tests
- [ ] Implement CI/CD pipeline with GitHub Actions
- [ ] Add API rate limiting
- [ ] Implement caching layer (Redis/ElastiCache)
- [ ] Add monitoring and alerting (CloudWatch Dashboards)
- [ ] Multi-region deployment
- [ ] Add WebSocket support for real-time features

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

For questions or issues:
- Open a [GitHub Issue](https://github.com/yourusername/Serverless-AWS-Lambda-SAM-/issues)
- Check the [reports/](reports/) folder for detailed documentation

---

## 🙏 Acknowledgments

- [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) - Enable Express.js on Lambda
- [AWS SAM](https://aws.amazon.com/serverless/sam/) - Serverless Application Model
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) - Infrastructure as Code
