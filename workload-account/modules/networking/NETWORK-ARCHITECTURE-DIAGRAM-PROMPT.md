# Enterprise Zero-Trust Network Architecture Diagram Generation Prompt

## 🎨 Comprehensive Image Generation Prompt for AI Tools

Copy and paste this prompt to genersional enterprise networking architecture diagram:

---

**Create a highly detailed, professional enterprise network architecture diagram for a zero-trust AWS hub-and-spoke networking design with the following specifications:**

## **Overall Layout & Style:**

- **Style**: Enterprise-grade network architecture diagram, clean and professional
- **Colors**: Use AWS-standard colors - Blue for VPCs, Orange for security components, Green for allowed traffic, Red for blocked/critical paths
- **Format**: Large horizontal layout (1920x1080 minimum), suitable for technical documentation
- **Background**: Light gray background with subtle grid lines
- **Typography**: Clear, readable fonts (Arial/Helvetica), consistent sizing hierarchy

## **Main Architecture Components (Left to Right Flow):**

### **1. Internet & External Access (Far Left)**

- **Internet Cloud** symbol at the top left
- Label: "Internet" with cloud icon
- Color: Light blue with white text
- Show bidirectional arrows (ingress/egress traffic)

### **2. Egress VPC (Hub) - Central Control Plane**

**Container**: Large rectangular container labeled "**Egress VPC (Hub)**"
**Color**: Blue header with light blue background
**CIDR**: Show "10.1.0.0/16" label

**Internal Components (Top to Bottom):**

**A. Public Subnets (Top Row)**

- Three boxes labeled "Public Subnet AZ-A", "Public Subnet AZ-B", "Public Subnet AZ-C"
- Color: Light green background
- CIDR labels: "10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"
- Each contains: **NAT Gateway** icon with "NAT-GW" label

**B. Internet Gateway**

- Single box at top center labeled "**Internet Gateway**"
- Color: Orange
- Connected to Internet with thick green arrow (bidirectional)
- Connected to Public Subnets with green arrows

**C. Firewall Subnets (Middle Row)**

- Three boxes labeled "Firewall Subnet AZ-A", "Firewall Subnet AZ-B", "Firewall Subnet AZ-C"
- Color: Red background with white text
- CIDR labels: "10.1.10.0/28", "10.1.10.16/28", "10.1.10.32/28"
- Each contains: **AWS Network Firewall Endpoint** icon

**D. TGW Subnets (Bottom Row)**

- Three boxes labeled "TGW Subnet AZ-A", "TGW Subnet AZ-B", "TGW Subnet AZ-C"
- Color: Purple background
- CIDR labels: "10.1.10.48/28", "10.1.10.64/28", "10.1.10.80/28"
- Each contains: **Transit Gateway Attachment** icon

### **3. AWS Network Firewall (Center)**

**Container**: Prominent central box labeled "**AWS Network Firewall**"
**Color**: Red gradient background
**Features Box** (inside):

- "Stateful Allowlist"
- "Fail-Close Policy"
- "DROP_STRICT Default"
- "Change Protection: ENABLED"

**Allowed Domains List** (side panel):

- ".amazonaws.com"
- ".github.com"
- ".githubusercontent.com"
- ".docker.elastic.co"
- ".ghcr.io"

**Protection Features** (bottom):

- Delete Protection: ✅
- Policy Change Protection: ✅
- Subnet Change Protection: ✅

### **4. Transit Gateway (Center-Bottom)**

**Container**: Hexagonal shape labeled "**Transit Gateway**"
**Color**: Purple with white text
**Configuration Details**:

- "Appliance Mode: ENABLED"
- "Default RT Association: DISABLED"
- "Default RT Propagation: DISABLED"
- "Custom Inspection Route Table"

### **5. Workload VPC (Spoke) - Right Side**

**Container**: Large rectangular container labeled "**Workload VPC (Spoke)**"
**Color**: Blue header with light blue background
**CIDR**: Show "10.0.0.0/16" label

**Security Badges** (top right):

- ❌ "NO Internet Gateway"
- ❌ "NO NAT Gateway"
- ✅ "Private Subnets Only"
- ✅ "VPC Endpoints"

**Internal Components:**

**A. Private Subnets (Top Row)**

- Three boxes labeled "Private Subnet AZ-A", "Private Subnet AZ-B", "Private Subnet AZ-C"
- Color: Light blue background
- CIDR labels: "10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"
- Each contains: **EKS Nodes** and **Application Pods** icons

**B. Database Subnets (Middle Row)**

- Three boxes labeled "DB Subnet AZ-A", "DB Subnet AZ-B", "DB Subnet AZ-C"
- Color: Dark blue background
- CIDR labels: "10.0.48.0/24", "10.0.49.0/24", "10.0.50.0/24"
- Each contains: **RDS** icon

**C. VPC Endpoints Section (Bottom)**

- Container labeled "**VPC Endpoints (Private AWS Access)**"
- Color: Green background

**Interface Endpoints** (left column):

- ECR (API & DKR)
- EKS
- EC2
- SSM/SSM Messages
- CloudWatch Logs
- STS
- ELB/Auto Scaling
- SQS/SNS

**Gateway Endpoints** (right column):

- S3 (with policy icon)

**Restricted Endpoints** (highlighted):

- Secrets Manager (with policy shield)
- KMS (with policy shield)

### **6. Security & Monitoring Components (Right Side)**

**VPC Flow Logs Box**:

- Label: "VPC Flow Logs"
- Color: Yellow background
- Destinations: "Security Account S3"
- Format: "Parquet/OCSF"
- Retention: "365 days"

**Lambda Controller Box**:

- Label: "Inspection Controller"
- Color: Orange background
- Function: "Fail-Close Enforcement"
- Triggers: "Firewall Health Monitoring"

## **Traffic Flow Arrows & Paths:**

### **Egress Traffic Flow (Green Arrows)**

1. **Workload → TGW**: Thick green arrow from Private Subnets to Transit Gateway
   - Label: "0.0.0.0/0 → TGW"
2. **TGW → Firewall**: Green arrow from TGW to Network Firewall
   - Label: "Inspection Route Table"
3. **Firewall → NAT**: Green arrow from Firewall to NAT Gateways
   - Label: "Allowed Traffic Only"
4. **NAT → Internet**: Green arrow from NAT to Internet Gateway
   - Label: "Egress to Internet"

### **Ingress Traffic Flow (Blue Arrows)**

1. **Internet → IGW**: Blue arrow from Internet to Internet Gateway
   - Label: "Ingress Traffic"
2. **IGW → Firewall**: Blue arrow with "IGW Edge Route Table" label
3. **Firewall → TGW**: Blue arrow labeled "Inspected Traffic"
4. **TGW → Workload**: Blue arrow to ALB/NLB in workload VPC
   - Label: "To Load Balancers"

### **Blocked Traffic (Red X Arrows)**

- Show red X arrows for blocked paths:
  - Direct Workload → Internet (blocked)
  - Unauthorized domains → Firewall (blocked)
  - Compromised traffic → Fail-close (blocked)

### **VPC Endpoint Traffic (Purple Arrows)**

- Purple arrows from workload subnets to VPC endpoints
- Label: "Private AWS API Access"
- No internet traversal shown

## **Data Flow Indicators & Labels:**

### **Traffic Volume Indicators**

- Small data flow icons showing:
  - "High Volume" on main egress path
  - "Secure" on VPC endpoint paths
  - "Monitored" on all paths with flow logs

### **Security Checkpoints**

- Shield icons at each inspection point:
  - Network Firewall (main shield)
  - VPC Endpoint Policies (small shields)
  - Security Groups (micro shields)

### **Performance Metrics**

- Small performance indicators:
  - "< 5ms latency" on VPC endpoints
  - "Multi-AZ HA" on NAT Gateways
  - "99.99% uptime" on Transit Gateway

## **Legend & Key (Bottom Right):**

Create a comprehensive legend box:

**Traffic Types:**

- Green arrow (thick): "Allowed Egress Traffic"
- Blue arrow (thick): "Allowed Ingress Traffic"
- Purple arrow (medium): "VPC Endpoint Traffic"
- Red X arrow: "Blocked/Denied Traffic"
- Yellow arrow: "Flow Logs to Security Account"

**Security Levels:**

- Green shield: "Allowed/Secure"
- Red shield: "Blocked/Restricted"
- Orange shield: "Monitored/Inspected"

**Component Types:**

- Blue boxes: "VPC/Subnets"
- Red boxes: "Security Components"
- Purple boxes: "Transit/Routing"
- Green boxes: "Allowed Services"

## **Annotations & Technical Details:**

### **CIDR Blocks (clearly labeled)**

- Workload VPC: 10.0.0.0/16
- Egress VPC: 10.1.0.0/16
- No CIDR overlap indication

### **Availability Zones**

- Show "AZ-A", "AZ-B", "AZ-C" labels consistently
- Multi-AZ deployment indicators

### **Security Posture Indicators**

- "Zero-Trust" badge on workload VPC
- "Fail-Close" badge on firewall
- "Least-Privilege" badge on VPC endpoints

### **Compliance Indicators**

- "PCI-DSS Ready" badge
- "SOC 2 Type II" badge
- "HIPAA Compliant" badge

## **Title & Header Information:**

- **Main Title**: "Enterprise Zero-Trust Hub-and-Spoke Network Architecture"
- **Subtitle**: "AWS Multi-AZ Deployment with Centralized Egress Inspection"
- **Footer**: "Production-Ready | Fail-Close Security | Regulatory Compliant"

## **Technical Specifications for AI:**

- **Resolution**: 1920x1080 minimum (prefer 2560x1440)
- **Format**: PNG with transparent background option
- **Text**: Use clear, readable fonts (minimum 10pt)
- **Icons**: Use AWS official icons where possible
- **Spacing**: Ensure adequate white space between components
- **Alignment**: All elements properly aligned and balanced
- **Color Contrast**: Ensure text is readable on all backgrounds

## **Visual Style Guidelines:**

- Use consistent rounded corners (5px radius) on all containers
- Apply subtle drop shadows for depth (2px offset, 20% opacity)
- Use consistent icon sizes (24px for small, 48px for large)
- Maintain proper visual hierarchy with font sizes (16pt titles, 12pt labels, 10pt details)
- Include subtle gradients in container backgrounds
- Use consistent line weights (2px for main arrows, 1px for borders)

## **Advanced Features to Include:**

### **Route Table Visualization**

- Small route table icons showing:
  - "0.0.0.0/0 → TGW" in workload private subnets
  - "Workload CIDR → Firewall" in IGW edge table
  - "0.0.0.0/0 → Firewall" in TGW subnets

### **Security Policy Visualization**

- Policy document icons showing:
  - VPC Endpoint policies (deny-by-default)
  - Firewall rules (allowlist)
  - Security group rules (least-privilege)

### **Monitoring Integration**

- CloudWatch icons showing:
  - VPC Flow Logs collection
  - Firewall metrics
  - Lambda function monitoring

---

## 🎯 Alternative Simplified Prompt

If the above is too complex, use this shorter version:

**"Create a professional AWS network architecture diagram showing:**

- **Left**: Internet → Internet Gateway → NAT Gateways (3 AZs)
- **Center**: AWS Network Firewall (red, fail-close) → Transit Gateway (purple)
- **Right**: Workload VPC with private subnets, database subnets, and VPC endpoints
- **Traffic Flow**: Green arrows for allowed traffic, red X for blocked traffic
- **Security**: Show zero-trust design with no direct internet access from workloads
- **Style**: Enterprise-grade, AWS colors, clear labels, professional layout
- **Include**: CIDR blocks, AZ labels, security badges, and comprehensive legend"

## 📝 Usage Instructions

1. **Copy the main prompt** above
2. **Paste into your preferred AI tool**:

   - ChatGPT (GPT-4 with DALL-E) - Best for technical diagrams
   - Claude with image generation
   - Midjourney - Excellent for professional layouts
   - Stable Diffusion - Free alternative

3. **Request modifications** if needed:

   - "Make it more technical with port numbers"
   - "Simplify for executive presentation"
   - "Add more security details"
   - "Use dark theme"

4. **Generate multiple versions**:
   - High-level overview
   - Detailed technical version
   - Security-focused version
   - Compliance-focused version

## 🔄 Prompt Variations

**For Security Focus:**
"Emphasize the security aspects - show all blocked paths, security policies, and compliance badges prominently"

**For Technical Detail:**
"Add technical details like port numbers, protocols, route table entries, and specific AWS service endpoints"

**For Executive Presentation:**
"Simplify for business audience - focus on security benefits, compliance, and high-level architecture"

**For Troubleshooting Guide:**
"Add troubleshooting elements - show common failure points, monitoring locations, and diagnostic paths"

---

## 📊 Expected Diagram Elements

Your generated diagram should clearly show:

✅ **Zero-Trust Architecture** - No direct internet access from workloads
✅ **Hub-and-Spoke Design** - Centralized egress inspection
✅ **Multi-AZ High Availability** - Components across 3 availability zones
✅ **Fail-Close Security** - Network firewall with strict allowlist
✅ **VPC Endpoint Strategy** - Private AWS service access
✅ **Traffic Flow Clarity** - Clear ingress/egress paths
✅ **Security Boundaries** - Visual separation of trust zones
✅ **Compliance Indicators** - PCI-DSS, SOC 2, HIPAA ready
✅ **Monitoring Integration** - VPC Flow Logs and security monitoring

This comprehensive prompt will generate a professional network architecture diagram that showcases your sophisticated zero-trust networking design suitable for enterprise and regulatory environments.
