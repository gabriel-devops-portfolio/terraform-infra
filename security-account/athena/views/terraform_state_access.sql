CREATE OR REPLACE VIEW security_terraform_state_access AS
SELECT
  time,
  api.operation,
  user_identity.arn AS principal,
  src_endpoint.ip   AS source_ip,
  account_uid,
  region
FROM amazon_security_lake_glue_db.amazon_cloudtrail
WHERE api.request.object.key LIKE '%terraform.tfstate%';
