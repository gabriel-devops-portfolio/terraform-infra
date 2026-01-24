# EKS Backup and Restore Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying a comprehensive backup and restore solution for the production EKS cluster `pilotgab-prod`. The solution includes:

- **Velero**: Kubernetes-native backup and restore
- **EBS Snapshots**: Automated volume-level backups
- **Cross-Region Replication**: Disaster recovery capabilities
- **Monitoring & Alerting**: CloudWatch-based backup monitoring

## Architecture Components

### 1. Backup Components
- **Velero Operator**: Manages Kubernetes resource backups
- **S3 Storage**: Primary backup storage with encryption
- **EBS Snapshots**: Volume-level backup via Lambda functions
- **Cross-Region Replication**: DR backup copies in us-west-2

### 2. Restore Components
- **Velero CLI**: Command-line restore operations
- **Automated Restore**: Scheduled restore testing
- **Volume Restore**: EBS snapshot-based volume recovery

## Prerequisites

### 1. Required Tools
```bash
# Install Velero CLI
curl -fsSL -o velero-v1.12.1-linux-amd64.tar.gz https://github.com/vmware-tanzu/velero/releases/download/v1.12.1/velero-v1.12.1-linux-amd64.tar.gz
tar -xvf velero-v1.12.1-linux-amd64.tar.gz
sudo mv velero-v1.12.1-linux-amd64/velero /usr/local/bin/

# Verify installation
velero version --client-only
```

### 2. AWS Permissions
Ensure your AWS credentials have the following permissions:
- EKS cluster access
- S3 bucket management
- EC2 snapshot operations
- IAM role management
- Lambda function deployment

### 3. Kubernetes Access
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name pilotgab-prod

# Verify access
kubectl get nodes
```

## Deployment Steps

### Step 1: Deploy Terraform Infrastructure

1. **Navigate to Production Environment**:
   ```bash
   cd terraform-infra/workload-account/environments/production
   ```

2. **Review Configuration**:
   ```bash
   # Check current configuration
   terraform plan -target=module.eks_backup
   ```

3. **Deploy Backup Infrastructure**:
   ```bash
   # Deploy the backup module
   terraform apply -target=module.eks_backup
   ```

4. **Verify Infrastructure Deployment**:
   ```bash
   # Check S3 buckets
   aws s3 ls | grep backup

   # Check Lambda functions
   aws lambda list-functions --query 'Functions[?contains(FunctionName, `backup`)]'

   # Check IAM roles
   aws iam list-roles --query 'Roles[?contains(RoleName, `velero`)]'
   ```

### Step 2: Install Velero in EKS Cluster

1. **Install Velero Server Components**:
   ```bash
   # Get the Velero IAM role ARN from Terraform output
   VELERO_ROLE_ARN=$(terraform output -raw eks_backup_velero_iam_role_arn)
   VELERO_BUCKET=$(terraform output -raw eks_backup_velero_bucket_name)

   # Install Velero
   velero install \
     --provider aws \
     --plugins velero/velero-plugin-for-aws:v1.8.0 \
     --bucket $VELERO_BUCKET \
     --backup-location-config region=us-east-1 \
     --snapshot-location-config region=us-east-1 \
     --service-account-annotations eks.amazonaws.com/role-arn=$VELERO_ROLE_ARN \
     --no-secret
   ```

2. **Verify Velero Installation**:
   ```bash
   # Check Velero pods
   kubectl get pods -n velero

   # Check backup storage location
   velero backup-location get

   # Check volume snapshot location
   velero snapshot-location get
   ```

### Step 3: Configure Backup Schedules

1. **Apply Scheduled Backups**:
   ```bash
   # The Terraform deployment already created scheduled backups
   # Verify they exist
   velero schedule get

   # Check backup schedule details
   velero schedule describe daily-backup
   velero schedule describe weekly-backup
   ```

2. **Create Custom Backup Schedules** (Optional):
   ```bash
   # Create application-specific backup
   velero schedule create app-backup \
     --schedule="0 3 * * *" \
     --include-namespaces="production,staging" \
     --ttl=720h

   # Create namespace-specific backup
   velero schedule create critical-apps \
     --schedule="0 */6 * * *" \
     --selector="tier=critical" \
     --ttl=168h
   ```

### Step 4: Test Backup and Restore

1. **Create Test Backup**:
   ```bash
   # Create a test namespace with sample resources
   kubectl create namespace backup-test
   kubectl create configmap test-config --from-literal=key=value -n backup-test
   kubectl create secret generic test-secret --from-literal=password=secret123 -n backup-test

   # Create manual backup
   velero backup create test-backup-$(date +%Y%m%d-%H%M%S) \
     --include-namespaces backup-test \
     --wait
   ```

2. **Test Restore Process**:
   ```bash
   # Delete test namespace
   kubectl delete namespace backup-test

   # Restore from backup
   BACKUP_NAME=$(velero backup get -o json | jq -r '.items[0].metadata.name')
   velero restore create test-restore-$(date +%Y%m%d-%H%M%S) \
     --from-backup $BACKUP_NAME \
     --wait

   # Verify restoration
   kubectl get all -n backup-test
   kubectl get configmap test-config -n backup-test -o yaml
   ```

3. **Run Backup Verification Script**:
   ```bash
   # Copy the verification script from the ConfigMap
   kubectl get configmap backup-restore-examples -n velero -o jsonpath='{.data.backup-verification\.sh}' > backup-verification.sh
   chmod +x backup-verification.sh

   # Run verification
   ./backup-verification.sh --test --report
   ```

### Step 5: Configure Monitoring and Alerting

1. **Create SNS Topic for Notifications** (Optional):
   ```bash
   # Create SNS topic
   aws sns create-topic --name eks-backup-alerts

   # Subscribe email to topic
   aws sns subscribe \
     --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:eks-backup-alerts \
     --protocol email \
     --notification-endpoint your-email@company.com
   ```

2. **Update Terraform with SNS Topic**:
   ```hcl
   # In terraform.tfvars
   backup_notification_topic_arn = "arn:aws:sns:us-east-1:ACCOUNT-ID:eks-backup-alerts"
   ```

3. **Apply Monitoring Configuration**:
   ```bash
   terraform apply -var="backup_notification_topic_arn=arn:aws:sns:us-east-1:ACCOUNT-ID:eks-backup-alerts"
   ```

### Step 6: Validate Cross-Region DR Setup

1. **Verify Cross-Region Replication**:
   ```bash
   # Check DR region bucket
   aws s3 ls --region us-west-2 | grep dr-backups

   # Verify replication status
   aws s3api get-bucket-replication --bucket $(terraform output -raw eks_backup_velero_bucket_name)
   ```

2. **Test DR Restore Capability**:
   ```bash
   # Configure Velero for DR region (in DR cluster)
   velero backup-location create primary-region \
     --provider aws \
     --bucket $(terraform output -raw eks_backup_velero_bucket_name) \
     --config region=us-east-1

   # List available backups from primary region
   velero backup get --backup-location primary-region
   ```

## Operational Procedures

### Daily Operations

1. **Monitor Backup Status**:
   ```bash
   # Check recent backups
   velero backup get

   # Check for failed backups
   velero backup get --selector="velero.io/backup-status=Failed"

   # Review backup logs
   velero backup logs <backup-name>
   ```

2. **Monitor EBS Snapshots**:
   ```bash
   # Check recent snapshots
   aws ec2 describe-snapshots \
     --owner-ids self \
     --filters "Name=tag:EKSCluster,Values=pilotgab-prod" \
     --query 'Snapshots[?StartTime>=`'$(date -d '1 day ago' -u +%Y-%m-%dT%H:%M:%S.000Z)'`]'
   ```

### Weekly Operations

1. **Backup Verification**:
   ```bash
   # Run comprehensive verification
   ./backup-verification.sh --test --report

   # Review backup retention
   velero backup get --show-labels
   ```

2. **Cleanup Old Resources**:
   ```bash
   # The Lambda cleanup function runs automatically
   # Check cleanup logs
   aws logs filter-log-events \
     --log-group-name /aws/lambda/pilotgab-prod-backup-cleanup \
     --start-time $(date -d '1 week ago' +%s)000
   ```

### Monthly Operations

1. **DR Testing**:
   ```bash
   # Perform monthly DR restore test
   # Document in DR test log
   ```

2. **Review and Update**:
   - Review backup retention policies
   - Update backup schedules if needed
   - Review monitoring alerts and thresholds

## Troubleshooting

### Common Issues

1. **Velero Pod Not Starting**:
   ```bash
   # Check pod status
   kubectl describe pod -n velero -l app.kubernetes.io/name=velero

   # Check service account annotations
   kubectl describe sa velero -n velero

   # Verify IAM role trust policy
   aws iam get-role --role-name pilotgab-prod-velero-role
   ```

2. **Backup Failures**:
   ```bash
   # Check backup details
   velero backup describe <backup-name> --details

   # Check Velero logs
   kubectl logs -n velero deployment/velero

   # Verify S3 bucket permissions
   aws s3 ls s3://$(terraform output -raw eks_backup_velero_bucket_name)/
   ```

3. **Restore Issues**:
   ```bash
   # Check restore status
   velero restore describe <restore-name> --details

   # Check for resource conflicts
   kubectl get events --sort-by='.lastTimestamp' | grep -i error

   # Verify target namespace exists
   kubectl get namespaces
   ```

### Emergency Procedures

1. **Complete Cluster Recovery**:
   ```bash
   # 1. Deploy new EKS cluster
   # 2. Install Velero with same configuration
   # 3. Restore from latest backup
   velero restore create emergency-restore-$(date +%Y%m%d-%H%M%S) \
     --from-backup <latest-backup-name> \
     --wait
   ```

2. **Cross-Region Failover**:
   ```bash
   # 1. Deploy EKS cluster in DR region
   # 2. Configure Velero with primary region bucket access
   # 3. Restore from cross-region backup
   ```

## Security Considerations

1. **Encryption**: All backups are encrypted using AWS KMS
2. **Access Control**: IAM roles limit backup/restore permissions
3. **Network Security**: S3 buckets have public access blocked
4. **Audit Logging**: All operations are logged to CloudWatch

## Compliance and Governance

1. **Retention Policies**: Configurable retention periods
2. **Audit Trail**: Complete backup/restore operation logs
3. **Data Classification**: Backup data inherits source classification
4. **Geographic Restrictions**: Cross-region replication for DR

## Support and Contacts

- **Infrastructure Team**: infrastructure@company.com
- **On-Call Support**: oncall@company.com
- **Documentation**: [Internal Wiki Link]
- **Runbooks**: [Runbook Repository Link]

## Appendix

### A. Terraform Outputs Reference
```bash
# Get all backup-related outputs
terraform output | grep backup
```

### B. Velero Command Reference
```bash
# Common Velero commands
velero backup create <name> --include-namespaces <ns>
velero restore create <name> --from-backup <backup-name>
velero schedule create <name> --schedule <cron>
velero backup delete <name> --confirm
```

### C. AWS CLI Reference
```bash
# EBS snapshot commands
aws ec2 describe-snapshots --owner-ids self
aws ec2 create-snapshot --volume-id <vol-id>
aws ec2 delete-snapshot --snapshot-id <snap-id>
```
