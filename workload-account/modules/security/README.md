# Security Automation Module (Fail-Close)

This module implements an automated fail-close mechanism for the centralized network firewall architecture. It uses an AWS Lambda function to monitor the health of the AWS Network Firewall endpoints and dynamically updates the Transit Gateway (TGW) route table to block traffic if the firewall becomes unhealthy.

## 🛡️ Architecture

- **Lambda Function (`inspection_controller`)**:
  - Polls Network Firewall status.
  - Updates TGW route table.
  - Fail-Open: Points default route to Egress VPC attachment (healthy).
  - Fail-Close: Points default route to "blackhole" (unhealthy).

- **EventBridge**:
  - **Scheduled Rule**: Runs every 1 minute to check health.
  - **Pattern Rule**: Reacts immediately to Network Firewall state change events.

- **IAM**:
  - Grants Lambda permission to `DescribeFirewall` and `ManageTGWRoutes`.

## Usage

```hcl
module "security_automation" {
  source = "../modules/security"

  env                  = "prod"
  region               = "us-east-1"
  tgw_route_table_id   = "tgw-rtb-123456"
  egress_attachment_id = "tgw-attach-123456"
  firewall_name        = "prod-network-firewall"
  enable_fail_close    = true
}
```

## Inputs

| Name                   | Description                             | Type     | Default | Required |
| ---------------------- | --------------------------------------- | -------- | ------- | :------: |
| `env`                  | Environment name                        | `string` | -       |   yes    |
| `region`               | AWS Region                              | `string` | -       |   yes    |
| `tgw_route_table_id`   | TGW Inspection Route Table ID to manage | `string` | -       |   yes    |
| `egress_attachment_id` | TGW Attachment ID for the Egress VPC    | `string` | -       |   yes    |
| `firewall_name`        | Name of the Network Firewall to monitor | `string` | -       |   yes    |
| `enable_fail_close`    | Enable the automation                   | `bool`   | `true`  |    no    |

## Logic

1. **Health Check**: `network-firewall:DescribeFirewall` is called.
2. **Evaluation**:
   - If **ALL** firewall endpoints (sync states) are `HEALTHY` -> **Pass**.
   - If **ANY** endpoint is `UNHEALTHY` or `DEGRADED` -> **Fail**.
3. **Action**:
   - **Pass**: Ensure default route (`0.0.0.0/0`) points to `egress_attachment_id`.
   - **Fail**: Ensure default route (`0.0.0.0/0`) is a **Blackhole**.

## Notes

- This is a critical component for regulated environments where "failing open" (bypassing inspection) is not acceptable.
- The Lambda function logs to CloudWatch Logs: `/aws/lambda/{env}_inspection_controller`.
