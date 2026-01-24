# AWS Route53 Public Zone Module

This module creates a public Route53 hosted zone.

## Usage

```hcl
module "public_zone" {
  source = "../modules/aws_route53_zone_public"

  domain_name = "example.com"
}
```

## Inputs

| Name          | Description                | Type     | Default              | Required |
| ------------- | -------------------------- | -------- | -------------------- | :------: |
| `domain_name` | The desired domain's name. | `string` | `"app.pilotgab.com"` |    no    |

## Outputs

| Name           | Description            |
| -------------- | ---------------------- |
| `zone_id`      | Route53 hosted zone ID |
| `name_servers` | Route53 name servers   |
| `domain_name`  | Domain name            |
| `arn`          | Route53 zone ARN       |
| `zone_name`    | Route53 zone name      |
