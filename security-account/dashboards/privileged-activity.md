Dashboard: Root & AssumedRole Activity

🎯 Purpose
	•	Detect compromised credentials
	•	Monitor privilege abuse
	•	Detect root usage (should be zero)

⸻

📊 Visualisations

A. Root Account Usage (Metric)
	•	Filter:
  user.identity.type : "Root"

 •	Metric: Count
  If this > 0 → incident.

B. AssumedRole Activity Over Time (Line)
	•	Filter:
  user.identity.type : "AssumedRole"

C. Privileged API Calls (Table)

Filter:
 api.operation IN (
  "AttachRolePolicy",
  "PutBucketPolicy",
  "CreateAccessKey",
  "UpdateAssumeRolePolicy"
)

Columns:
	•	time
	•	api.operation
	•	user.identity.arn
	•	src_endpoint.ip

