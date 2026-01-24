#!/bin/bash

# EKS Backup Verification Script for ${cluster_name}
# This script verifies the integrity and completeness of backups

set -e

CLUSTER_NAME="${cluster_name}"
VELERO_BUCKET="${velero_bucket}"
NAMESPACE="velero"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "$${GREEN}[INFO]$${NC} $1"
}

log_warn() {
    echo -e "$${YELLOW}[WARN]$${NC} $1"
}

log_error() {
    echo -e "$${RED}[ERROR]$${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    if ! command -v velero &> /dev/null; then
        log_error "velero CLI is not installed or not in PATH"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        log_error "aws CLI is not installed or not in PATH"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Verify Velero installation
verify_velero_installation() {
    log_info "Verifying Velero installation..."

    # Check if Velero namespace exists
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Velero namespace '$NAMESPACE' not found"
        return 1
    fi

    # Check if Velero deployment is running
    if ! kubectl get deployment velero -n $NAMESPACE &> /dev/null; then
        log_error "Velero deployment not found in namespace '$NAMESPACE'"
        return 1
    fi

    # Check deployment status
    READY_REPLICAS=$(kubectl get deployment velero -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment velero -n $NAMESPACE -o jsonpath='{.spec.replicas}')

    if [ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]; then
        log_error "Velero deployment is not ready. Ready: $READY_REPLICAS, Desired: $DESIRED_REPLICAS"
        return 1
    fi

    log_info "Velero installation verified successfully"
}

# Check backup storage location
verify_backup_storage() {
    log_info "Verifying backup storage location..."

    # Check if backup storage location exists
    if ! velero backup-location get default &> /dev/null; then
        log_error "Default backup storage location not found"
        return 1
    fi

    # Check storage location status
    BSL_PHASE=$(velero backup-location get default -o json | jq -r '.items[0].status.phase')
    if [ "$BSL_PHASE" != "Available" ]; then
        log_error "Backup storage location is not available. Status: $BSL_PHASE"
        return 1
    fi

    # Verify S3 bucket access
    if ! aws s3 ls s3://$VELERO_BUCKET/ &> /dev/null; then
        log_error "Cannot access S3 bucket: $VELERO_BUCKET"
        return 1
    fi

    log_info "Backup storage verification passed"
}

# Check volume snapshot location
verify_volume_snapshots() {
    log_info "Verifying volume snapshot location..."

    # Check if volume snapshot location exists
    if ! velero snapshot-location get default &> /dev/null; then
        log_error "Default volume snapshot location not found"
        return 1
    fi

    # Check snapshot location status
    VSL_PHASE=$(velero snapshot-location get default -o json | jq -r '.items[0].status.phase')
    if [ "$VSL_PHASE" != "Available" ]; then
        log_error "Volume snapshot location is not available. Status: $VSL_PHASE"
        return 1
    fi

    log_info "Volume snapshot location verification passed"
}

# Verify recent backups
verify_recent_backups() {
    log_info "Verifying recent backups..."

    # Get backups from last 7 days
    RECENT_BACKUPS=$(velero backup get --output json | jq -r '.items[] | select(.status.phase == "Completed" and (.metadata.creationTimestamp | fromdateiso8601) > (now - 7*24*3600)) | .metadata.name')

    if [ -z "$RECENT_BACKUPS" ]; then
        log_warn "No completed backups found in the last 7 days"
        return 1
    fi

    BACKUP_COUNT=$(echo "$RECENT_BACKUPS" | wc -l)
    log_info "Found $BACKUP_COUNT completed backups in the last 7 days"

    # Verify each recent backup
    for backup in $RECENT_BACKUPS; do
        log_info "Verifying backup: $backup"

        # Check backup details
        BACKUP_STATUS=$(velero backup describe $backup --output json | jq -r '.status.phase')
        BACKUP_ERRORS=$(velero backup describe $backup --output json | jq -r '.status.errors // 0')
        BACKUP_WARNINGS=$(velero backup describe $backup --output json | jq -r '.status.warnings // 0')

        if [ "$BACKUP_STATUS" != "Completed" ]; then
            log_error "Backup $backup status is not Completed: $BACKUP_STATUS"
            continue
        fi

        if [ "$BACKUP_ERRORS" -gt 0 ]; then
            log_warn "Backup $backup has $BACKUP_ERRORS errors"
        fi

        if [ "$BACKUP_WARNINGS" -gt 0 ]; then
            log_warn "Backup $backup has $BACKUP_WARNINGS warnings"
        fi

        log_info "Backup $backup verification passed"
    done
}

# Test backup and restore functionality
test_backup_restore() {
    log_info "Testing backup and restore functionality..."

    TEST_NAMESPACE="backup-test-$(date +%s)"
    TEST_BACKUP="test-backup-$(date +%s)"
    TEST_RESTORE="test-restore-$(date +%s)"

    # Create test namespace and resources
    log_info "Creating test namespace: $TEST_NAMESPACE"
    kubectl create namespace $TEST_NAMESPACE

    # Create test resources
    kubectl create configmap test-config --from-literal=key=value -n $TEST_NAMESPACE
    kubectl create secret generic test-secret --from-literal=password=secret123 -n $TEST_NAMESPACE

    # Create test backup
    log_info "Creating test backup: $TEST_BACKUP"
    velero backup create $TEST_BACKUP --include-namespaces $TEST_NAMESPACE --wait

    # Verify backup completed
    BACKUP_STATUS=$(velero backup describe $TEST_BACKUP --output json | jq -r '.status.phase')
    if [ "$BACKUP_STATUS" != "Completed" ]; then
        log_error "Test backup failed with status: $BACKUP_STATUS"
        cleanup_test_resources
        return 1
    fi

    # Delete test namespace
    log_info "Deleting test namespace for restore test"
    kubectl delete namespace $TEST_NAMESPACE

    # Wait for namespace deletion
    while kubectl get namespace $TEST_NAMESPACE &> /dev/null; do
        sleep 2
    done

    # Restore from backup
    log_info "Creating test restore: $TEST_RESTORE"
    velero restore create $TEST_RESTORE --from-backup $TEST_BACKUP --wait

    # Verify restore completed
    RESTORE_STATUS=$(velero restore describe $TEST_RESTORE --output json | jq -r '.status.phase')
    if [ "$RESTORE_STATUS" != "Completed" ]; then
        log_error "Test restore failed with status: $RESTORE_STATUS"
        cleanup_test_resources
        return 1
    fi

    # Verify restored resources
    if ! kubectl get configmap test-config -n $TEST_NAMESPACE &> /dev/null; then
        log_error "Test configmap was not restored"
        cleanup_test_resources
        return 1
    fi

    if ! kubectl get secret test-secret -n $TEST_NAMESPACE &> /dev/null; then
        log_error "Test secret was not restored"
        cleanup_test_resources
        return 1
    fi

    log_info "Backup and restore test passed successfully"

    # Cleanup test resources
    cleanup_test_resources
}

# Cleanup test resources
cleanup_test_resources() {
    log_info "Cleaning up test resources..."

    # Delete test namespace if it exists
    if kubectl get namespace $TEST_NAMESPACE &> /dev/null; then
        kubectl delete namespace $TEST_NAMESPACE
    fi

    # Delete test backup if it exists
    if velero backup get $TEST_BACKUP &> /dev/null; then
        velero backup delete $TEST_BACKUP --confirm
    fi

    # Delete test restore if it exists
    if velero restore get $TEST_RESTORE &> /dev/null; then
        velero restore delete $TEST_RESTORE --confirm
    fi
}

# Check EBS snapshots
verify_ebs_snapshots() {
    log_info "Verifying EBS snapshots..."

    # Get recent snapshots for the cluster
    RECENT_SNAPSHOTS=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=tag:EKSCluster,Values=$CLUSTER_NAME" "Name=tag:BackupType,Values=EKS-EBS-Automated" \
        --query 'Snapshots[?StartTime>=`'$(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S.000Z)'`]' \
        --output json | jq -r '.[].SnapshotId')

    if [ -z "$RECENT_SNAPSHOTS" ]; then
        log_warn "No recent EBS snapshots found for cluster $CLUSTER_NAME"
        return 1
    fi

    SNAPSHOT_COUNT=$(echo "$RECENT_SNAPSHOTS" | wc -l)
    log_info "Found $SNAPSHOT_COUNT recent EBS snapshots"

    # Verify snapshot status
    for snapshot in $RECENT_SNAPSHOTS; do
        SNAPSHOT_STATE=$(aws ec2 describe-snapshots --snapshot-ids $snapshot --query 'Snapshots[0].State' --output text)
        if [ "$SNAPSHOT_STATE" != "completed" ]; then
            log_warn "Snapshot $snapshot is not completed. State: $SNAPSHOT_STATE"
        else
            log_info "Snapshot $snapshot is completed"
        fi
    done
}

# Generate verification report
generate_report() {
    log_info "Generating verification report..."

    REPORT_FILE="backup-verification-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "EKS Backup Verification Report"
        echo "=============================="
        echo "Cluster: $CLUSTER_NAME"
        echo "Date: $(date)"
        echo "Velero Bucket: $VELERO_BUCKET"
        echo ""

        echo "Backup Summary:"
        velero backup get
        echo ""

        echo "Recent Backup Details:"
        LATEST_BACKUP=$(velero backup get --output json | jq -r '.items[0].metadata.name')
        if [ "$LATEST_BACKUP" != "null" ]; then
            velero backup describe $LATEST_BACKUP
        fi
        echo ""

        echo "Storage Locations:"
        velero backup-location get
        velero snapshot-location get
        echo ""

        echo "EBS Snapshots (Last 7 days):"
        aws ec2 describe-snapshots \
            --owner-ids self \
            --filters "Name=tag:EKSCluster,Values=$CLUSTER_NAME" \
            --query 'Snapshots[?StartTime>=`'$(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S.000Z)'`].{SnapshotId:SnapshotId,StartTime:StartTime,State:State,VolumeSize:VolumeSize}' \
            --output table

    } > $REPORT_FILE

    log_info "Verification report saved to: $REPORT_FILE"
}

# Main execution
main() {
    log_info "Starting EKS backup verification for cluster: $CLUSTER_NAME"

    check_prerequisites
    verify_velero_installation
    verify_backup_storage
    verify_volume_snapshots
    verify_recent_backups
    verify_ebs_snapshots

    if [ "$${1:-}" = "--test" ]; then
        test_backup_restore
    fi

    if [ "$${1:-}" = "--report" ]; then
        generate_report
    fi

    log_info "Backup verification completed successfully"
}

# Run main function with all arguments
main "$@"
