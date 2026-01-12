1️⃣ Dashboard: GuardDuty Findings by Severity

🎯 Purpose (SOC use)
	•	Spot high-severity threats fast
	•	Track trends (spikes = incidents)
	•	Prioritise response

⸻

📊 Visualisations to added

A. Findings by Severity (Bar chart)
	•	Index: securitylake_guardduty*
	•	X-axis: severity.label
	•	Y-axis: Count of findings

Severity levels:
	•	LOW
	•	MEDIUM
	•	HIGH
	•	CRITICAL

⸻

B. Findings Over Time (Line chart)
	•	X-axis: time
	•	Y-axis: Count
	•	Split series: severity.label

Shows attack bursts.

⸻

C. Top Finding Types (Table)
	•	Columns:
	•	finding.type
	•	severity.label
	•	resource.resource_type
