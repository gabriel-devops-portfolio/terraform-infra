#!/bin/bash

# OpenSearch manual Deployment Script for Jaeger Tracing
# This script deploys the OpenSearch domain for Jaeger distributed tracing

set -e

echo "🚀 OpenSearch Deployment for Jaeger Tracing"
echo "============================================"

# Configuration
ENVIRONMENT="production"
WORKDIR="environments/${ENVIRONMENT}"

# Verify we're in the correct directory
if [ ! -d "$WORKDIR" ]; then
    echo "❌ ERROR: Directory $WORKDIR not found"
    echo "   Please run this script from terraform-infra/workload-account/"
    exit 1
fi

cd "$WORKDIR"

# Verify AWS credentials
echo "🔍 Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ ERROR: AWS credentials not configured"
    echo "   Please configure AWS CLI credentials first"
    exit 1
fi

echo "✅ AWS Account: $ACCOUNT_ID"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

# Validate Terraform configuration
echo "🔍 Validating Terraform configuration..."
terraform validate

# Plan the OpenSearch deployment
echo "📋 Planning OpenSearch deployment..."
terraform plan -target=module.opensearch -out=opensearch.tfplan

# Confirm deployment
echo ""
echo "🎯 Ready to deploy OpenSearch domain for Jaeger tracing"
echo "   This will create:"
echo "   - OpenSearch domain (jaeger-production)"
echo "   - IAM roles for IRSA integration"
echo "   - Security groups and KMS encryption"
echo "   - CloudWatch log groups"
echo ""
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Deploying OpenSearch infrastructure..."
    terraform apply opensearch.tfplan

    # Get outputs
    echo ""
    echo "📊 Deployment Results:"
    echo "====================="

    OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_endpoint 2>/dev/null || echo "Not available")
    JAEGER_ROLE_ARN=$(terraform output -raw jaeger_elasticsearch_role_arn 2>/dev/null || echo "Not available")

    echo "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"
    echo "Jaeger IAM Role ARN: $JAEGER_ROLE_ARN"

    # Clean up plan file
    rm -f opensearch.tfplan

    echo ""
    echo "✅ OpenSearch deployment completed successfully!"
    echo ""
    echo "🔧 Next Steps:"
    echo "1. Update Jaeger Helm values with the OpenSearch endpoint"
    echo "2. Deploy Jaeger via ArgoCD or Helm"
    echo "3. Configure OpenTelemetry collectors to send traces to Jaeger"
    echo ""
    echo "📝 Jaeger Configuration:"
    echo "   OpenSearch Host: $OPENSEARCH_ENDPOINT"
    echo "   Port: 443"
    echo "   Scheme: https"
    echo "   IAM Role: $JAEGER_ROLE_ARN"

else
    echo "❌ Deployment cancelled"
    rm -f opensearch.tfplan
    exit 0
fi
