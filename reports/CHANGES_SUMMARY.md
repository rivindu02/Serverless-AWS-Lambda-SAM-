# Infrastructure Changes Summary

## Date: January 2, 2026

## Overview
Implemented proper network isolation by creating **separate private subnets** for Lambda functions (Application Tier) and MongoDB ECS containers (Data Tier).

---

## Changes Made

### 1. Network Architecture Changes

#### 1.1 Subnet Structure (Terraform/main.tf)
**BEFORE:**
- 2 private subnets shared by both Lambda and MongoDB
  - `private_1`: 10.0.2.0/24
  - `private_2`: 10.0.3.0/24

**AFTER:**
- 4 separate private subnets with clear tier separation
  - **Lambda Subnets** (Application Tier):
    - `lambda_private_1`: 10.0.2.0/24 (us-east-2a)
    - `lambda_private_2`: 10.0.3.0/24 (us-east-2b)
  - **ECS/MongoDB Subnets** (Data Tier):
    - `ecs_private_1`: 10.0.4.0/24 (us-east-2a)
    - `ecs_private_2`: 10.0.5.0/24 (us-east-2b)

#### 1.2 Variable Updates (Terraform/variables.tf)
**Replaced:**
```terraform
variable "private_subnet_1_cidr"
variable "private_subnet_2_cidr"
```

**With:**
```terraform
variable "lambda_private_subnet_1_cidr"
variable "lambda_private_subnet_2_cidr"
variable "ecs_private_subnet_1_cidr"
variable "ecs_private_subnet_2_cidr"
```

### 2. ECS Service Configuration (Terraform/ecs.tf)

#### 2.1 Subnet Assignment
**Changed from:**
```terraform
subnets = [aws_subnet.private_1.id, aws_subnet.private_2.id]
```

**To:**
```terraform
subnets = [aws_subnet.ecs_private_1.id, aws_subnet.ecs_private_2.id]
```

#### 2.2 Public IP Assignment 🔒 **SECURITY FIX**
**Changed from:**
```terraform
assign_public_ip = true  # INCORRECT - exposes database to internet
```

**To:**
```terraform
assign_public_ip = false  # CORRECT - uses NAT Gateway
```

**Impact:** MongoDB containers are now fully private with no public IP exposure.

### 3. EFS Configuration (Terraform/database.tf)

**Updated mount targets to use ECS subnets:**
```terraform
# Mount target 1: aws_subnet.ecs_private_1.id
# Mount target 2: aws_subnet.ecs_private_2.id
```

Ensures EFS is only accessible from the Data Tier.

### 4. SAM Template Updates (template.yaml)

#### 4.1 Parameter Changes
**Changed from:**
```yaml
SubnetIds:
  Type: 'AWS::SSM::Parameter::Value<CommaDelimitedList>'
```

**To:**
```yaml
LambdaSubnetIds:
  Type: 'AWS::SSM::Parameter::Value<CommaDelimitedList>'
  Default: '/school-mgmt/vpc/lambda-private-subnets'
```

#### 4.2 VPC Configuration
**Updated Lambda to use dedicated subnets:**
```yaml
VpcConfig:
  SecurityGroupIds:
    - !Ref LambdaSecurityGroup
  SubnetIds: !Ref LambdaSubnetIds
```

### 5. SSM Parameters (Terraform/outputs.tf)

**Added new SSM parameters:**
```terraform
# For Lambda
/school-mgmt/vpc/lambda-private-subnets

# For ECS
/school-mgmt/vpc/ecs-private-subnets
```

**Removed:**
```terraform
/school-mgmt/vpc/private-subnets  # Generic parameter
```

### 6. Terraform Outputs (Terraform/outputs.tf)

#### 6.1 New Outputs
- `lambda_private_subnet_1_id`
- `lambda_private_subnet_2_id`
- `lambda_private_subnet_ids`
- `ecs_private_subnet_1_id`
- `ecs_private_subnet_2_id`
- `ecs_private_subnet_ids`
- `network_architecture` (detailed ASCII diagram)

#### 6.2 Deprecated Outputs (kept for backwards compatibility)
- `private_subnet_1_id` → now points to `lambda_private_1`
- `private_subnet_2_id` → now points to `lambda_private_2`
- `private_subnet_ids` → now points to Lambda subnets

---

## Benefits of Changes

### 🔒 Security Improvements
1. **Network Isolation**: Lambda and MongoDB are in separate subnets
2. **Zero Public Exposure**: MongoDB has no public IP
3. **Least Privilege**: Security groups enforce strict access control
4. **Defense in Depth**: Multiple layers of network security

### 🏗️ Architecture Improvements
1. **Clear Tier Separation**: Application vs Data layers
2. **Compliance**: Follows AWS Well-Architected Framework
3. **Scalability**: Each tier can scale independently
4. **Maintainability**: Clear subnet naming and purpose

### 🔍 Visibility Improvements
1. **Network Architecture Document**: Comprehensive documentation
2. **ASCII Diagrams**: Visual representation of network flow
3. **SSM Parameters**: Clear parameter naming convention
4. **Terraform Outputs**: Detailed output descriptions

---

## Deployment Steps

### 1. Terraform Deployment
```bash
cd Terraform

# Review changes
terraform plan

# Apply infrastructure changes
terraform apply

# Verify outputs
terraform output network_architecture
```

### 2. SAM Deployment
```bash
# Build Lambda container
sam build

# Deploy with updated parameters
sam deploy --guided
```

### 3. Verification Steps
```bash
# Check SSM parameters
aws ssm get-parameter --name /school-mgmt/vpc/lambda-private-subnets
aws ssm get-parameter --name /school-mgmt/vpc/ecs-private-subnets

# Verify ECS service
aws ecs describe-services \
  --cluster rvk-school-mgmt-cluster \
  --services mongo-service

# Check Lambda configuration
aws lambda get-function-configuration \
  --function-name SchoolApiFunction
```

---

## Breaking Changes

### ⚠️ Action Required

**If you have existing infrastructure deployed:**

1. **Terraform State**: The subnet resource names have changed
   - You may need to import new resources or use `terraform state mv`
   
2. **SAM Parameters**: Update parameter references
   - Old: `--parameter-overrides SubnetIds=/school-mgmt/vpc/private-subnets`
   - New: `--parameter-overrides LambdaSubnetIds=/school-mgmt/vpc/lambda-private-subnets`

3. **ECS Tasks**: Will be redeployed to new subnets
   - Existing tasks will be stopped
   - New tasks will start in ECS subnets
   - Brief downtime expected during transition

### 🔄 Migration Path

**Option 1: Clean Deployment (Recommended for Dev)**
```bash
# Destroy existing infrastructure
terraform destroy

# Deploy new infrastructure
terraform apply
```

**Option 2: State Migration (For Production)**
```bash
# Move state resources (examples)
terraform state mv aws_subnet.private_1 aws_subnet.lambda_private_1
terraform state mv aws_subnet.private_2 aws_subnet.lambda_private_2

# Then apply to create new ECS subnets
terraform apply
```

---

## Testing Checklist

- [ ] Terraform plan shows expected changes
- [ ] Terraform apply completes successfully
- [ ] All SSM parameters created
- [ ] Lambda function deployed to new subnets
- [ ] Lambda can connect to MongoDB
- [ ] MongoDB container has no public IP
- [ ] MongoDB can pull Docker images (via NAT)
- [ ] EFS mounts successfully
- [ ] API Gateway endpoints respond correctly
- [ ] CloudWatch logs are being generated

---

## Rollback Plan

If issues occur:

1. **Revert Terraform changes:**
   ```bash
   git checkout HEAD~1 Terraform/
   terraform apply
   ```

2. **Revert SAM template:**
   ```bash
   git checkout HEAD~1 template.yaml
   sam deploy
   ```

3. **Monitor CloudWatch logs** for errors

---

## Files Modified

### Terraform Files
1. `Terraform/main.tf` - Added separate Lambda and ECS subnets
2. `Terraform/variables.tf` - Updated subnet CIDR variables
3. `Terraform/ecs.tf` - Changed subnet references and fixed public IP
4. `Terraform/database.tf` - Updated EFS mount targets
5. `Terraform/outputs.tf` - Added new outputs and SSM parameters

### SAM Files
6. `template.yaml` - Updated parameter references

### Documentation
7. `reports/NETWORK_ARCHITECTURE.md` - New comprehensive network documentation
8. `reports/CHANGES_SUMMARY.md` - This file

---

## Support and Troubleshooting

### Common Issues

**Issue**: Lambda can't connect to MongoDB
- **Solution**: Verify security group rules allow traffic on port 27017
- **Check**: `aws ec2 describe-security-group-rules --filters Name=group-id,Values=<lambda-sg-id>`

**Issue**: MongoDB can't pull Docker images
- **Solution**: Verify NAT Gateway is attached and routes are correct
- **Check**: `aws ec2 describe-nat-gateways` and `aws ec2 describe-route-tables`

**Issue**: EFS mount failures
- **Solution**: Ensure mount targets are in correct subnets
- **Check**: `aws efs describe-mount-targets --file-system-id <fs-id>`

### Monitoring Commands

```bash
# View Terraform outputs
terraform output

# Check ECS service status
aws ecs describe-services --cluster rvk-school-mgmt-cluster --services mongo-service

# View Lambda logs
aws logs tail /aws/lambda/SchoolApiFunction --follow

# Check network architecture
terraform output network_architecture
```

---

## Next Steps

### Recommended Enhancements
1. **VPC Endpoints**: Add endpoints for S3, ECR, CloudWatch to reduce NAT costs
2. **Network ACLs**: Add subnet-level access control for additional security
3. **VPC Flow Logs**: Enable for security monitoring and troubleshooting
4. **Automated Testing**: Create integration tests for network connectivity
5. **Cost Optimization**: Monitor NAT Gateway usage and consider alternatives

### Documentation Updates
- [x] Network architecture documented
- [x] Security groups documented
- [ ] Runbook for incident response
- [ ] Cost analysis document
- [ ] Disaster recovery plan

---

## Sign-off

**Changes Completed**: January 2, 2026  
**Infrastructure Version**: 2.0  
**Status**: ✅ Ready for Deployment

**Reviewed By**: Infrastructure Team  
**Approved By**: DevOps Lead
