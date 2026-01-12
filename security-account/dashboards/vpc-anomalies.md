Dashboard: VPC Traffic Anomalies

🎯 Purpose
	•	Detect lateral movement
	•	Detect scanning
	•	Detect exfiltration attempts

⸻

📊 Visualisations

A. Rejected Traffic (Bar chart)
Filter:
 action : "REJECT"

•	Group by:
•	dstport
•	srcaddr

B. Top Talkers (Network Map / Table)
	•	Fields:
	•	srcaddr
	•	dstaddr
	•	Count

C. Unusual Ports (Table)

Filter:
 dstport NOT IN (80, 443, 22, 3306, 5432)
