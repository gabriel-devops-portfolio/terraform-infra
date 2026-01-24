# EKS Backup and Restore Guide

## Overview

This guide provides instructions for backing up and restoring your EKS cluster `${cluster_name}` using Velero and AWS native services.

## Backup Components

### 1. Velero Backups
- **Storage**: S3 bucket `${velero_bucket}`
- **Schedule**: Daily at 2 AM UTC
- **Retention**: 30 days (configurable)
- **Scope**: All namespaces except system namespaces

### 2. EBS Volume Snapshots
- **Automated**: Lambda function creates daily snapshots
- **Retention**: 30 days (configurable)
- **Scope**: All EBS volumes attached to cluster nodes

### 3. ETCD Backups (if applicable)
- **Storage**: Separate S3 bucket for ETCD data
- **Frequency**: As configured in backup schedule

## Manual Backup Operations

### Create an On-Demand Backup

```bash
# Full cluster backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces "*" \
  --snapshot-volumes=true

# Namespace-specific backup
velero backup create app-backup-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces "production,staging" \
  --snapshot-volumes=true

# Application-specific backup with labels
velero backup create app-specific-backup-$(date +%Y%m%d-%H%M%S) \
  --selector "app=my-application" \
  --snapshot-volumes=true
```

### List Available Backups

```bash
# List all backups
velero backup get

# Get backup details
velero backup describe <backup-name>

# Check backup logs
velero backup logs <backup-name>
```

## Restore Operations

### Full Cluster Restore

```bash
# Restore from latest backup
velero restore create restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup <backup-name>

# Restore with namespace mapping
velero restore create restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup <backup-name> \
  --namespace-mappings old-namespace:new-namespace
```

### Selective Restore

```bash
# Restore specific namespaces
velero restore create namespace-restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup <backup-name> \
  --include-namespaces "production,staging"

# Restore specific resources
velero restore create resource-restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup <backup-name> \
  --include-resources "deployments,services,configmaps"

# Restore with label selector
velero restore create app-restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup <backup-name> \
  --selector "app=my-application"
```

### Monitor Restore Progress

```bash
# Check restore status
velero restore get

# Get restore details
velero restore describe <restore-name>

# Check restore logs
velero restore logs <restore-name>
```

## Disaster Recovery Procedures

### Cross-Region Recovery

1. **Prepare DR Environment**:
   ```bash
   # Set up new EKS cluster in DR region
   # Configure Velero with cross-region S3 access
   ```

2. **Restore from Cross-Region Backup**:
   ```bash
   # Configure Velero to use primary region bucket
   velero backup-location create primary-region \
     --provider aws \
     --bucket ${velero_bucket} \
     --config region=us-east-1

   # List available backups from primary region
   velero backup get --backup-location primary-region

   # Restore from primary region backup
   velero restore create dr-restore-$(date +%Y%m%d-%H%M%S) \
     --from-backup <backup-name> \
     --backup-location primary-region
   ```

### EBS Volume Recovery

1. **Identify Required Snapshots**:
   ```bash
   # List snapshots for the cluster
   aws ec2 describe-snapshots \
     --owner-ids self \
     --filters "Name=tag:EKSCluster,Values=${cluster_name}"
   ```

2. **Create Volumes from Snapshots**:
   ```bash
   # Create volume from snapshot
   aws ec2 create-volume \
     --snapshot-id <snapshot-id> \
     --availability-zone <az> \
     --volume-type gp3
   ```

3. **Attach to New Instances**:
   ```bash
   # Attach volume to instance
   aws ec2 attach-volume \
     --volume-id <volume-id> \
     --instance-id <instance-id> \
     --device /dev/sdf
   ```

## Backup Verification

### Automated Verification

The backup system includes automated verification:
- Backup completion status monitoring
- CloudWatch alarms for backup failures
- Lambda functions for cleanup and maintenance

### Manual Verification

```bash
# Verify backup integrity
velero backup describe <backup-name> --details

# Test restore in isolated namespace
kubectl create namespace backup-test
velero restore create test-restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup <backup-name> \
  --include-namespaces "production" \
  --namespace-mappings "production:backup-test"

# Cleanup test namespace
kubectl delete namespace backup-test
```

## Troubleshooting

### Common Issues

1. **Backup Failures**:
   ```bash
   # Check Velero pod logs
   kubectl logs -n velero deployment/velero

   # Check backup status
   velero backup describe <backup-name>
   ```

2. **Restore Failures**:
   ```bash
   # Check restore logs
   velero restore logs <restore-name>

   # Check for resource conflicts
   kubectl get events --sort-by='.lastTimestamp'
   ```

3. **Permission Issues**:
   ```bash
   # Verify IAM role permissions
   aws sts get-caller-identity

   # Check service account annotations
   kubectl describe sa velero -n velero
   ```

### Support Contacts

- **Infrastructure Team**: [infrastructure@company.com]
- **On-Call**: [oncall@company.com]
- **Documentation**: [wiki.company.com/eks-backup]

## Best Practices

1. **Regular Testing**: Test restore procedures monthly
2. **Monitoring**: Set up alerts for backup failures
3. **Documentation**: Keep restore procedures updated
4. **Access Control**: Limit backup/restore permissions
5. **Encryption**: Ensure all backups are encrypted
6. **Retention**: Review and adjust retention policies regularly

## Compliance and Security

- All backups are encrypted using AWS KMS
- Access is controlled via IAM roles and policies
- Audit logs are maintained for all backup/restore operations
- Cross-region replication ensures disaster recovery capability
