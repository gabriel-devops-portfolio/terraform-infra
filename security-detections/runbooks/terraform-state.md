# 🚨 Terraform State Access Detection

## Severity
High

## Estimated Investigation Time
**45-75 minutes**

## Compliance Scope
- **SOC 2:** CC6.1 (Logical Access Controls)
- **PCI-DSS:** 8.2 (User Authentication)
- **HIPAA:** 164.312(a)(2) (Unique User Identification)
- **GDPR:** Article 32 (Security of Processing)

## Trigger

• Access to terraform.tfstate files outside approved CI/CD or backend roles
• CloudTrail event indicating S3 object access to Terraform state

⸻

## Why This Matters

Terraform state files stored in remote backends (S3) may contain:

• Sensitive infrastructure metadata
• IAM role and resource ARNs
• Provider configuration details
• Embedded secrets or outputs

Unauthorized access to Terraform state can lead to full infrastructure compromise.

⸻

## OpenSearch Query Example

```json
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "class_name": "API Activity"
          }
        },
        {
          "match": {
            "api.operation": "GetObject"
          }
        },
        {
          "wildcard": {
            "resources.uid": "*terraform.tfstate*"
          }
        }
      ],
      "must_not": [
        {
          "terms": {
            "actor.user.name": [
              "TerraformBackendRole",
              "GitHubActionsRole",
              "Jenkins-Terraform-Role"
            ]
          }
        }
      ]
    }
  },
  "sort": [
    {
      "time": {
        "order": "desc"
      }
    }
  ]
}
```

**Index Pattern:** `securitylake-cloudtrail-*`
**Key Fields:**
- `api.operation`: GetObject, PutObject, ListBucket
- `resources.uid`: S3 bucket/key containing "terraform.tfstate"
- `actor.user.name`: IAM role/user

**Approved Principals:**
- `TerraformBackendRole`
- `GitHubActionsRole`
- `Jenkins-Terraform-Role`

**AWS CLI Alternative:**
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=org-security-account-terraform-state-prod \
  --region us-east-1
```

⸻

## Investigation Steps

1. Identify the IAM principal that accessed the state file
2. Review CloudTrail event details (action, bucket, object key)
3. Validate source IP address and request time
4. Confirm whether access aligns with expected CI/CD activity
5. Review recent Terraform runs and backend logs

⸻

## Containment Actions

1. Immediately revoke or disable offending credentials
2. Restrict Terraform backend access to approved CI/CD roles only
3. Rotate any potentially exposed secrets or credentials
4. Temporarily lock state file access if compromise is suspected

⸻

## Remediation Steps

• Review and tighten IAM policies for the Terraform backend
• Enforce least privilege on S3 and DynamoDB state locking
• Ensure CloudTrail data events are enabled for state buckets
• Apply Service Control Policies to limit unauthorized access where feasible

⸻

## Validation

• Confirm no further unauthorized state access occurs
• Verify Terraform operations function correctly via CI/CD roles
• Ensure secrets rotation and access restrictions are complete
• Close alert once state integrity is confirmed

⸻

## Common False Positives

- **Manual Terraform runs:** Developer using admin credentials during incident response
- **State migration:** Infrastructure team moving state between backends
- **Disaster recovery:** Authorized restoration from backup state files

**Expected Frequency:** 0-1 occurrences per month (outside CI/CD)

⸻

## Escalation Criteria

**Escalate to Infrastructure Lead if:**
- Access was NOT from approved CI/CD pipeline
- Multiple state files accessed in short timeframe
- Unrecognized IAM principal or source IP
- Cannot confirm legitimacy within 30 minutes

**Notification:** Slack #infrastructure-security, Email: infra-lead@company.com

⸻

## DLQ Handling (Alert Delivery Failure)

If the alert was not delivered successfully:

1. Check SQS queue: soc-security-alerts-dlq
2. Identify failed alert messages
3. Investigate SNS, IAM, or notification destination issues
4. Manually notify SOC stakeholders if required
5. Clear DLQ messages after delivery is restored

⸻

## Related MITRE ATT&CK

• **T1552** – Unsecured Credentials (Credentials In Files - T1552.001)

**Tactic:** Credential Access

⸻

## Related Runbooks

- [Root Account Usage](./root-account.md) - If root credentials used for state access
- [GuardDuty Detection](./guardduty.md) - If credential compromise suspected

⸻

## References

- **Backend Bucket:** `org-security-account-terraform-state-prod`
- **Backend Bucket Policy:** `/security-account/backend-bootstrap/bucket-policy.tf`
- **Approved Roles:** See IAM roles in `/security-account/cross-account-roles/`

⸻

## SOC Note

Terraform state is a high-value target.
Access must be tightly controlled, monitored, and audited at all times.
