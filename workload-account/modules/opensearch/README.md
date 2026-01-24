# OpenSearch Module

This module provisions an AWS OpenSearch Service domain tailored for Jaeger tracing storage.

## Features

- **Encryption**: Enforces encryption at rest (KMS) and in transit (HTTPS/TLS).
- **Network Isolation**: Deployed within a VPC.
- **Access Control**: Fine-grained IAM access policies.
- **Logging**: Slow search/index and error logs published to CloudWatch.
- **High Availability**: Supports Multi-AZ deployments with dedicated master nodes.

## Usage

```hcl
module "opensearch" {
  source = "../modules/opensearch"

  environment       = "prod"
  vpc_id            = "vpc-123"
  vpc_cidr          = "10.0.0.0/16"
  subnet_ids        = ["subnet-1", "subnet-2", "subnet-3"]
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/..."
  oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/..."
}
```

## Inputs

| Name                       | Description                       | Type           | Default             |
| -------------------------- | --------------------------------- | -------------- | ------------------- |
| `environment`              | Environment name                  | `string`       | `"production"`      |
| `vpc_id`                   | VPC ID for deployment             | `string`       | -                   |
| `vpc_cidr`                 | VPC CIDR for security group rules | `string`       | -                   |
| `subnet_ids`               | List of subnet IDs                | `list(string)` | -                   |
| `instance_type`            | OpenSearch node instance type     | `string`       | `"t3.small.search"` |
| `instance_count`           | Number of data nodes              | `number`       | `3`                 |
| `dedicated_master_enabled` | Enable dedicated master nodes     | `bool`         | `true`              |
| `zone_awareness_enabled`   | Enable Multi-AZ                   | `bool`         | `true`              |
| `volume_size`              | EBS volume size (GB)              | `number`       | `20`                |

## Outputs

| Name                | Description                                     |
| ------------------- | ----------------------------------------------- |
| `domain_endpoint`   | OpenSearch domain endpoint URL                  |
| `domain_arn`        | ARN of the OpenSearch domain                    |
| `domain_id`         | ID of the OpenSearch domain                     |
| `kibana_endpoint`   | Endpoint for Kibana/OpenSearch Dashboards       |
| `security_group_id` | ID of the security group attached to the domain |
| `irsa_role_arn`     | ARN of the IAM role for Service Accounts        |
