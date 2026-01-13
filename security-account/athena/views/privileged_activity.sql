CREATE OR REPLACE VIEW security_privileged_activity AS
SELECT
  time,
  api.operation,
  user_identity.type       AS identity_type,
  user_identity.arn        AS principal,
  src_endpoint.ip          AS source_ip,
  account_uid,
  region
FROM amazon_security_lake_glue_db.amazon_cloudtrail
WHERE user_identity.type IN ('Root','AssumedRole');
