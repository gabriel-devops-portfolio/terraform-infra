#!/bin/bash
############################################
# OpenSearch Monitor Deployment Script
# Purpose: Upload SOC alerting monitors to OpenSearch
############################################

set -e

echo "🚀 OpenSearch Monitor Deployment Script"
echo "========================================"
echo ""

# Check if we're in the right directory
if [ ! -f "guardduty-monitor.json" ]; then
    echo "❌ Error: Run this script from security-account/soc-alerting/monitors directory"
    exit 1
fi

# Get OpenSearch endpoint
echo "📡 Getting OpenSearch endpoint..."
cd ../../opensearch
OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_endpoint 2>/dev/null | sed 's|https://||')

if [ -z "$OPENSEARCH_ENDPOINT" ]; then
    echo "❌ Error: Could not get OpenSearch endpoint. Has OpenSearch been deployed?"
    exit 1
fi

echo "✅ OpenSearch endpoint: $OPENSEARCH_ENDPOINT"
echo ""

# Get admin password from Secrets Manager
echo "🔐 Getting admin password from Secrets Manager..."
OPENSEARCH_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text \
  --region us-east-1 2>/dev/null)

if [ -z "$OPENSEARCH_PASSWORD" ]; then
    echo "❌ Error: Could not retrieve OpenSearch admin password"
    echo "   Make sure Secrets Manager secret 'opensearch-admin-password' exists"
    exit 1
fi

echo "✅ Password retrieved"
echo ""

# Return to monitors directory
cd ../soc-alerting/monitors

# Function to upload monitor
upload_monitor() {
    local file=$1
    local name=$(basename "$file" .json)

    echo "📤 Uploading $name..."

    response=$(curl -s -w "\n%{http_code}" -X POST \
      "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
      -H "Content-Type: application/json" \
      -u "admin:${OPENSEARCH_PASSWORD}" \
      -d @"$file")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
        monitor_id=$(echo "$body" | jq -r '._id' 2>/dev/null)
        if [ -n "$monitor_id" ] && [ "$monitor_id" != "null" ]; then
            echo "   ✅ Monitor created successfully: $monitor_id"
        else
            echo "   ✅ Monitor uploaded (response: $http_code)"
        fi
    else
        echo "   ❌ Failed to upload monitor (HTTP $http_code)"
        echo "   Response: $body"
        return 1
    fi
}

# Check if monitors already exist
echo "🔍 Checking for existing monitors..."
existing_monitors=$(curl -s -X GET \
  "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors/_search" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  | jq -r '.hits.hits[] | ._source.name' 2>/dev/null)

if [ -n "$existing_monitors" ]; then
    echo "⚠️  Found existing monitors:"
    echo "$existing_monitors"
    echo ""
    read -p "Do you want to continue? This will create duplicate monitors. (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled"
        exit 0
    fi
fi

echo ""
echo "📋 Uploading monitors..."
echo "========================"
echo ""

# Upload each monitor
upload_monitor "guardduty-monitor.json"
echo ""

upload_monitor "root-account-monitor.json"
echo ""

upload_monitor "terraform-state-monitor.json"
echo ""

upload_monitor "vpc-anomalies-monitor.json"
echo ""

echo "========================"
echo "✅ Monitor deployment complete!"
echo ""

# List all monitors
echo "📋 Current monitors:"
curl -s -X GET \
  "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors/_search" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  | jq -r '.hits.hits[] | {id: ._id, name: ._source.name, enabled: ._source.enabled}' 2>/dev/null

echo ""
echo "🎯 Next steps:"
echo "1. Verify monitors are enabled in OpenSearch Dashboards"
echo "2. Create SNS destinations if you haven't already"
echo "3. Update destination IDs in monitor configurations"
echo "4. Test each monitor to verify alerts are sent"
echo ""
echo "📖 See MONITOR-CONFIGURATION-REVIEW.md for detailed instructions"
