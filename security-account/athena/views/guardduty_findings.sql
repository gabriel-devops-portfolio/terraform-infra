CREATE OR REPLACE VIEW security_guardduty_findings AS
SELECT
  time,
  severity,
  finding_type,
  activity_name,
  resource_type,
  resource_uid,
  account_uid,
  region
FROM amazon_security_lake_glue_db.amazon_guardduty_finding;
