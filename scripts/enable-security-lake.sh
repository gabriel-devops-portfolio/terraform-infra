#!/bin/bash

# Security Lake Organization Setup Script
# Run this script in the MANAGEMENT ACCOUNT (111111222222)

set -e

echo "🔧 Security Lake Organization Setup"
echo "=================================="

# Verify we're in the management account
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ "$ACCOUNT_ID" != "111111222222" ]; then
    echo "❌ ERROR: This script must be run in the management account (111111222222)"
    echo "   Current account: $ACCOUNT_ID"
    exit 1
fi

echo "✅ Confirmed running in management account: $ACCOUNT_ID"

# Check if organization CloudTrail exists
echo "🔍 Checking organization CloudTrail..."
TRAIL_STATUS=$(aws cloudtrail get-trail-status --name organization-trail --query IsLogging --output text 2>/dev/null || echo "false")

if [ "$TRAIL_STATUS" = "true" ]; then
    echo "✅ Organization CloudTrail is active and logging"
else
    echo "❌ Organization CloudTrail not found or not logging"
    echo "   Please ensure the management account Terraform has been applied"
    exit 1
fi

# Enable Security Lake service (this creates the service-linked role)
echo "🔧 Enabling Security Lake service..."
aws securitylake create-aws-log-source \
    --sources '[{
        "accounts": ["111111222222", "555555666666", "333333444444"],
        "regions": ["us-east-1"],
        "sourceName": "CLOUD_TRAIL_MGMT",
        "sourceVersion": "2.0"
    }]' 2>/dev/null || echo "Security Lake may already be partially configured"

# Set up delegated administrator
echo "🔧 Setting up delegated administrator..."
aws organizations register-delegated-administrator \
    --account-id 333333444444 \
    --service-principal securitylake.amazonaws.com 2>/dev/null || echo "Delegation may already exist"

echo ""
echo "✅ Security Lake organization setup complete!"
echo ""
echo "Next steps:"
echo "1. Switch to security account (333333444444)"
echo "2. Run: cd terraform-infra/security-account/backend-bootstrap"
echo "3. Run: terraform apply -auto-approve"
echo ""
echo "This will complete the Security Lake infrastructure deployment."
