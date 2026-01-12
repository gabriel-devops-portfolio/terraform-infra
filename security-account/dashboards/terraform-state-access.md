4️⃣ Dashboard: Terraform State Access

🎯 Purpose
	•	Detect infrastructure compromise
	•	Monitor access to sensitive IaC state
	•	Audit DevOps actions

⸻

📊 Visualisations

A. State Access Over Time (Line)

Filter:
 api.request.object.key : "*terraform.tfstate*"

B. Who Accessed State (Table)

Columns:
	•	time
	•	user.identity.arn
	•	api.operation
	•	src_endpoint.ip

⸻

C. Failed Access Attempts (Metric)

Filter:
 event.outcome : "Failure"
