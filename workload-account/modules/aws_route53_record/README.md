# Route53 Record Module

This module abstracts the creation of AWS Route53 records.

## Usage

```hcl
module "dns_record" {
  source = "../modules/aws_route53_record"

  zone_id = "Z1234567890"
  name    = "app.example.com"
  type    = "A"
  ttl     = "300"
  records = ["1.1.1.1"]
}
```

## Inputs

| Name      | Description                                       | Type           | Default | Required |
| --------- | ------------------------------------------------- | -------------- | ------- | :------: |
| `zone_id` | The ID of the hosted zone to contain this record. | `string`       | `""`    |   yes    |
| `name`    | The name of the record.                           | `string`       | `""`    |   yes    |
| `type`    | The record type (A, CNAME, etc).                  | `string`       | `"A"`   |    no    |
| `ttl`     | The TTL of the record.                            | `string`       | `"5"`   |    no    |
| `records` | A string list of records.                         | `list(string)` | `[]`    |    no    |
