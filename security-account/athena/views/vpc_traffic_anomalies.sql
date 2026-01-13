CREATE OR REPLACE VIEW security_vpc_traffic_anomalies AS
SELECT
  time,
  srcaddr,
  dstaddr,
  srcport,
  dstport,
  action,
  packets,
  bytes,
  account_uid,
  region
FROM amazon_security_lake_glue_db.amazon_vpc_flow
WHERE action = 'REJECT'
   OR dstport NOT IN (80,443,22,3306,5432);
