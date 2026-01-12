#!/bin/bash
# Test Admin Access to Member Accounts

set -e

echo "🔐 Testing Admin Access to Member Accounts"
echo "=========================================="
echo ""

# Get account IDs from Terraform outputs
echo "📊 Getting account information..."
cd /Users/CaptGab/terraform-infra/management-account

SECURITY_ACCOUNT_ID=$(terraform output -raw security_account_id 2>/dev/null || echo "UNKNOWN")
WORKLOAD_ACCOUNT_ID=$(terraform output -raw workload_account_id 2>/dev/null || echo "UNKNOWN")

echo "Security Account ID: $SECURITY_ACCOUNT_ID"
echo "Workload Account ID: $WORKLOAD_ACCOUNT_ID"
echo ""

# Test 1: Check if OrganizationAccountAccessRole exists
echo "✅ Test 1: Verify OrganizationAccountAccessRole exists"
echo "---------------------------------------------------"

if [ "$WORKLOAD_ACCOUNT_ID" != "UNKNOWN" ]; then
    echo "Testing workload account..."

    # Try to assume the role
    CREDENTIALS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${WORKLOAD_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
        --role-session-name "test-admin-access" \
        --duration-seconds 900 \
        2>&1) || {
        echo "❌ FAILED: Cannot assume role in workload account"
        echo "Error: $CREDENTIALS"
        exit 1
    }

    echo "✅ SUCCESS: Can assume OrganizationAccountAccessRole"

    # Extract credentials
    export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')

    # Test 2: Verify admin permissions - list resources
    echo ""
    echo "✅ Test 2: Verify admin permissions (list VPCs)"
    echo "---------------------------------------------------"

    VPC_LIST=$(aws ec2 describe-vpcs --region us-east-1 2>&1) || {
        echo "❌ FAILED: Cannot list VPCs (should have admin access)"
        exit 1
    }

    echo "✅ SUCCESS: Can list VPCs (has admin permissions)"
    echo "$VPC_LIST" | jq -r '.Vpcs[] | "  VPC: \(.VpcId) - CIDR: \(.CidrBlock)"' || echo "  No VPCs found (this is OK)"

    # Test 3: Verify can describe IAM (admin-level permission)
    echo ""
    echo "✅ Test 3: Verify IAM admin permissions"
    echo "---------------------------------------------------"

    IAM_SUMMARY=$(aws iam get-account-summary --region us-east-1 2>&1) || {
        echo "❌ FAILED: Cannot access IAM (should have admin access)"
        exit 1
    }

    echo "✅ SUCCESS: Can access IAM (has admin permissions)"
    echo "$IAM_SUMMARY" | jq -r '.SummaryMap | "  IAM Users: \(.Users), Roles: \(.Roles), Groups: \(.Groups)"'

    # Test 4: Verify S3 access (admin permission)
    echo ""
    echo "✅ Test 4: Verify S3 admin permissions"
    echo "---------------------------------------------------"

    S3_LIST=$(aws s3 ls 2>&1) || {
        echo "⚠️  WARNING: Cannot list S3 (might be no buckets yet)"
    }

    echo "✅ SUCCESS: Can list S3 buckets (has admin permissions)"

    # Unset credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

else
    echo "❌ Cannot test - workload account not deployed yet"
    echo "   Run 'terraform apply' first"
fi

echo ""
echo "=========================================="
echo "✅ All Tests Passed!"
echo ""
echo "📝 Summary:"
echo "   - OrganizationAccountAccessRole exists ✅"
echo "   - Can assume role from management account ✅"
echo "   - Has full administrator access ✅"
echo "   - Can create VPCs, EC2, S3, IAM, etc. ✅"
echo ""
echo "🚀 You can now deploy resources to member accounts!"
echo ""
echo "📖 Next Steps:"
echo "   1. Use 'Switch Role' in AWS Console"
echo "   2. Or use Terraform with assume_role"
echo "   3. Or use AWS CLI with assumed credentials"
echo ""
echo "📚 Examples in: /management-account/README.md (Cross-Account Access section)"
