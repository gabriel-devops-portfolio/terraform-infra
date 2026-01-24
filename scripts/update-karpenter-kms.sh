#!/bin/bash
set -e

# Script to update Karpenter node-class.yaml files with actual EKS KMS key ARN
# This replaces the <EKS_KMS_KEY_ARN> placeholder with the real value from Terraform

echo "🔍 Retrieving EKS KMS Key ARN from Terraform..."

# Navigate to production environment
cd "$(dirname "$0")/../workload-account/environments/production"

# Get the KMS key ARN from Terraform output
KMS_ARN=$(terraform output -raw eks_kms_key_arn 2>/dev/null)

if [ -z "$KMS_ARN" ]; then
    echo "❌ Error: Could not retrieve eks_kms_key_arn from Terraform output."
    echo "   Please ensure you've run 'terraform apply' in the production environment."
    exit 1
fi

echo "✅ Found KMS Key ARN: $KMS_ARN"
echo ""

# Go back to repo root
cd "$(dirname "$0")/.."

# Update both node-class.yaml files
FILES=(
    "karpenter/node-class.yaml"
    "gitops-apps/prod/karpenter/node-class.yaml"
)

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "📝 Updating $FILE..."

        # Check if placeholder exists
        if grep -q "<EKS_KMS_KEY_ARN>" "$FILE"; then
            # Use sed to replace the placeholder (macOS compatible)
            sed -i '' "s|<EKS_KMS_KEY_ARN>|$KMS_ARN|g" "$FILE"
            echo "   ✅ Updated successfully"
        else
            echo "   ⚠️  No placeholder found (may already be updated)"
        fi
    else
        echo "⚠️  File not found: $FILE"
    fi
    echo ""
done

echo "🎉 All files updated with KMS Key ARN!"
echo ""
echo "📋 Next steps:"
echo "   1. Review the changes: git diff"
echo "   2. Deploy Karpenter IAM resources: cd workload-account/environments/production && terraform apply"
echo "   3. Update apps-karpenter.yaml with cluster endpoint"
echo "   4. Deploy Karpenter via ArgoCD"
