# 🔒 Security Groups Configuration

## Three-Tier "Handshake" Architecture

This document explains the security group configuration for the Lambda-ECS-EFS hybrid architecture.

## Security Philosophy

✅ **Least Privilege Principle**: Each resource only has access to what it needs  
✅ **Security Group Based**: Rules reference SG IDs, not IP addresses (flexible & secure)  
✅ **Granular Port Control**: Specific ports for specific purposes  
✅ **No Ingress to Lambda**: Lambda initiates all connections (defensive posture)

---

## 🔐 Security Group Matrix

| Resource          | SG Name            | Inbound                      | Outbound                                |
|-------------------|--------------------|-----------------------------|----------------------------------------|
| **Lambda (API)**  | RVK-mongo-db-sg    | None (initiates only)       | • Port 27017 → MongoDB SG<br>• Port 443 → Internet (HTTPS)<br>• Port 80 → Internet (HTTP) |
| **MongoDB (ECS)** | RVK-ecs-mongo-sg   | • Port 27017 ← Lambda SG    | • Port 2049 → EFS SG<br>• Port 443 → Internet (CloudWatch)<br>• Port 80/443 → Internet (Docker)<br>• Port 53 → Internet (DNS) |
| **EFS (Storage)** | mongo-efs-sg       | • Port 2049 ← MongoDB SG    | None required                          |

---

## 1️⃣ Lambda Security Group (RVK-mongo-db-sg)

### Purpose
Controls traffic for the Lambda function running the Express.js API (Application Tier)

### Configuration
```hcl
Name: RVK-mongo-db-sg
VPC: RVK-lambda-vpc
Tier: Application
```

### Rules

#### Inbound (Ingress)
**None** - Lambda is invoked by API Gateway; it doesn't accept direct connections

#### Outbound (Egress)

| Port  | Protocol | Destination         | Purpose                          |
|-------|----------|---------------------|----------------------------------|
| 27017 | TCP      | MongoDB SG          | Connect to MongoDB database       |
| 443   | HTTPS    | 0.0.0.0/0           | AWS API calls, external services  |
| 80    | HTTP     | 0.0.0.0/0           | Package downloads during builds   |

### Why These Rules?

**Port 27017 → MongoDB SG**
- Lambda needs to query/write to MongoDB
- Restricted to MongoDB SG only (not all instances)
- Uses Service Discovery (mongo.local:27017)

**Port 443 → Internet**
- CloudWatch Logs
- SSM Parameter Store
- AWS SDK API calls
- External API integrations (if needed)

**Port 80 → Internet**
- NPM package downloads during container builds
- Can be removed if packages are cached in image

---

## 2️⃣ MongoDB Security Group (RVK-ecs-mongo-sg)

### Purpose
Controls traffic for the ECS Fargate task running MongoDB (Data Tier)

### Configuration
```hcl
Name: RVK-ecs-mongo-sg
VPC: RVK-lambda-vpc
Tier: Data
```

### Rules

#### Inbound (Ingress)

| Port  | Protocol | Source              | Purpose                          |
|-------|----------|---------------------|----------------------------------|
| 27017 | TCP      | Lambda SG           | Accept database connections       |

#### Outbound (Egress)

| Port    | Protocol | Destination         | Purpose                          |
|---------|----------|---------------------|----------------------------------|
| 2049    | TCP      | EFS SG              | Mount EFS volume (NFS)           |
| 443     | HTTPS    | 0.0.0.0/0           | CloudWatch Logs                  |
| 80      | HTTP     | 0.0.0.0/0           | Docker image pulls               |
| 443     | HTTPS    | 0.0.0.0/0           | Docker image pulls (ECR)         |
| 53      | UDP      | 0.0.0.0/0           | DNS resolution                   |

### Why These Rules?

**Inbound: Port 27017 ← Lambda SG**
- Only Lambda can connect to MongoDB
- Source is restricted to Lambda SG ID (not IP range)
- Prevents unauthorized access from other resources

**Outbound: Port 2049 → EFS SG**
- MongoDB needs to mount the EFS volume for persistence
- WiredTiger engine writes data to `/data/db`
- Restricted to EFS SG only

**Outbound: Port 443 → Internet**
- Send container logs to CloudWatch
- Essential for monitoring and debugging
- ECS agent communicates with ECS service

**Outbound: Ports 80/443 → Internet**
- Pull MongoDB Docker image from Docker Hub or ECR
- Required during task startup
- Can use VPC Endpoints to avoid NAT costs

**Outbound: Port 53 → Internet**
- DNS resolution for pulling images
- Required for Service Discovery registration
- Resolves CloudWatch Logs endpoints

---

## 3️⃣ EFS Security Group (mongo-efs-sg)

### Purpose
Controls access to the EFS file system for MongoDB data persistence (Storage Tier)

### Configuration
```hcl
Name: mongo-efs-sg
VPC: RVK-lambda-vpc
Tier: Storage
```

### Rules

#### Inbound (Ingress)

| Port  | Protocol | Source              | Purpose                          |
|-------|----------|---------------------|----------------------------------|
| 2049  | TCP      | MongoDB SG          | Allow NFS mount from ECS         |

#### Outbound (Egress)
**None** - EFS doesn't initiate connections; it only responds to mount requests

### Why These Rules?

**Inbound: Port 2049 ← MongoDB SG**
- EFS uses NFS protocol (port 2049)
- Only MongoDB ECS tasks can mount the volume
- Prevents other resources from accessing database files
- Ensures data isolation

---

## 🔄 Traffic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        User/Client                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTPS (443)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API Gateway (HTTP API)                       │
│                     (Managed by AWS)                            │
└─────────────────────────────┬───────────────────────────────────┘
                              │ Invokes
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│         🔒 Lambda Security Group (RVK-mongo-db-sg)              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Lambda Function (Express.js API)                  │ │
│  │         • JWT Authentication                              │ │
│  │         • Request Validation (Zod)                        │ │
│  │         • Business Logic                                  │ │
│  └────────────────────────┬──────────────────────────────────┘ │
│                           │                                     │
└───────────────────────────┼─────────────────────────────────────┘
                            │
                            │ Port 27017 (TCP)
                            │ mongo.local:27017
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│         🔒 MongoDB Security Group (RVK-ecs-mongo-sg)            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         ECS Fargate Task (MongoDB)                        │ │
│  │         • WiredTiger Storage Engine                       │ │
│  │         • Journal & Checkpoints                           │ │
│  │         • Port 27017                                      │ │
│  └────────────────────────┬──────────────────────────────────┘ │
│                           │                                     │
└───────────────────────────┼─────────────────────────────────────┘
                            │
                            │ Port 2049 (NFS)
                            │ /data/db mount
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│           🔒 EFS Security Group (mongo-efs-sg)                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Amazon EFS (Elastic File System)                  │ │
│  │         • Encrypted at Rest                               │ │
│  │         • Multi-AZ Mount Targets                          │ │
│  │         • Persistent Storage                              │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Security Benefits

### 1. Defense in Depth
- **Multiple Layers**: Network (VPC) → Security Groups → Application (JWT)
- **Fail-Safe**: Even if one layer is breached, others provide protection
- **Auditable**: CloudTrail logs all security group changes

### 2. Least Privilege Access
- **Lambda**: Can only reach MongoDB and internet
- **MongoDB**: Can only be reached by Lambda
- **EFS**: Can only be mounted by MongoDB

### 3. No Public Exposure
- **Private Subnets**: Lambda and MongoDB have no public IPs
- **NAT Gateway**: Outbound internet access only
- **API Gateway**: Single, controlled entry point

### 4. Flexible & Maintainable
- **SG ID References**: Rules stay valid even if IPs change
- **Auto-Scaling**: New Lambda instances automatically get correct rules
- **Easy Updates**: Add/remove rules without touching infrastructure

---

## 🚨 Common Security Issues & Fixes

### Issue 1: Lambda Can't Connect to MongoDB
**Symptom**: Connection timeout or "Unable to connect"

**Check:**
```bash
# Verify Lambda SG has outbound rule to MongoDB SG on port 27017
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Verify MongoDB SG has inbound rule from Lambda SG
aws ec2 describe-security-groups --group-ids sg-yyyyy
```

**Fix**: Ensure security group rules reference each other correctly

### Issue 2: ECS Task Can't Pull Docker Image
**Symptom**: Task stuck in "PENDING" or "PROVISIONING"

**Check:**
```bash
# Verify MongoDB SG has outbound rules for ports 80, 443, 53
aws ec2 describe-security-groups --group-ids sg-yyyyy
```

**Fix**: Add egress rules for HTTP (80), HTTPS (443), and DNS (53)

### Issue 3: MongoDB Can't Mount EFS
**Symptom**: Task crashes with "mount failed" error

**Check:**
```bash
# Verify MongoDB SG has outbound rule to EFS SG on port 2049
# Verify EFS SG has inbound rule from MongoDB SG on port 2049
```

**Fix**: Add NFS (2049) rules between MongoDB and EFS security groups

### Issue 4: No CloudWatch Logs from ECS
**Symptom**: Logs don't appear in CloudWatch

**Check:**
```bash
# Verify MongoDB SG has outbound HTTPS (443) to 0.0.0.0/0
```

**Fix**: Add egress rule for port 443 to internet

---

## 🔍 Monitoring & Auditing

### CloudWatch Metrics
Monitor security group rule usage:
```bash
# VPC Flow Logs (enable for traffic analysis)
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

### Security Group Change Tracking
```bash
# CloudTrail logs all security group modifications
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress
```

### Recommended Alarms
- Unusual traffic patterns (VPC Flow Logs)
- Unauthorized security group changes (CloudTrail + EventBridge)
- Connection failures (application logs)

---

## 📋 Security Group Checklist

Before deploying, verify:

- [ ] Lambda SG allows outbound to MongoDB SG on port 27017
- [ ] Lambda SG allows outbound HTTPS (443) for AWS APIs
- [ ] MongoDB SG allows inbound from Lambda SG on port 27017
- [ ] MongoDB SG allows outbound to EFS SG on port 2049
- [ ] MongoDB SG allows outbound HTTPS (443) for CloudWatch
- [ ] MongoDB SG allows outbound HTTP/HTTPS (80/443) for Docker
- [ ] MongoDB SG allows outbound DNS (53) for resolution
- [ ] EFS SG allows inbound from MongoDB SG on port 2049
- [ ] No security group has inbound from 0.0.0.0/0 (except ALB if used)
- [ ] All security groups have descriptive names and tags

---

## 🔄 Updating Security Groups

### Terraform Method (Recommended)
```bash
cd Terraform/
terraform plan   # Review changes
terraform apply  # Apply updates
```

### Manual Method (Not Recommended)
```bash
# Add rule to Lambda SG
aws ec2 authorize-security-group-egress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 27017 \
  --source-group sg-yyyyy

# Remove rule from Lambda SG
aws ec2 revoke-security-group-egress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 27017 \
  --source-group sg-yyyyy
```

**Note**: Always use Terraform to maintain infrastructure as code

---

## 🎯 Best Practices

1. **Use Security Group IDs, Not CIDR Blocks**
   - More flexible when IPs change
   - Easier to audit and understand

2. **Be Specific with Ports**
   - Don't use `-1` (all protocols) unless necessary
   - Specify exact ports for each service

3. **Document All Rules**
   - Add descriptions to every rule
   - Explain why each rule is needed

4. **Regular Audits**
   - Review security groups quarterly
   - Remove unused rules
   - Check for overly permissive rules

5. **Use Tags**
   - Tag security groups by tier, environment, purpose
   - Makes filtering and management easier

6. **Test Changes in Dev First**
   - Never modify production security groups directly
   - Test in development environment
   - Use Terraform to promote changes

---

## 📚 Additional Resources

- [AWS Security Groups Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Terraform AWS Security Group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)

---

**Last Updated**: January 2, 2026  
**Version**: 2.0 (Granular Rules Implementation)
