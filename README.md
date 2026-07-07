# AWS Break/Fix Lab

A VPC-based AWS environment built entirely in Terraform, used to practice and document real infrastructure incident response. Each incident is deliberately introduced, diagnosed from symptoms, resolved, and written up as a troubleshooting record.

## Architecture

- **VPC** `10.0.0.0/16`
- **Public subnets** `10.0.1.0/24`, `10.0.2.0/24` (2 AZs) — host the ALB and NAT Gateway
- **Private subnets** `10.0.11.0/24`, `10.0.12.0/24` (2 AZs) — host the EC2 instances
- **Internet Gateway** — egress for public subnets
- **NAT Gateway** — outbound-only egress for private subnets
- **Application Load Balancer** — public entry point, forwards to instances
- **2x EC2 (t3.micro)** — nginx web app in private subnets, managed via SSM (no SSH keys)
- **DynamoDB** — application data store, accessed via VPC Gateway Endpoint
- **3 layered security groups** — ALB (public 80/443), App (from ALB only), DB (from App only)
- **Scoped IAM instance role** — least-privilege DynamoDB access + SSM
- **CloudWatch alarms + SNS** — observability and alerting

## Authentication

Access is via AWS IAM Identity Center (SSO) using a scoped admin identity. The root account is protected with MFA and not used for daily operations. Terraform authenticates through a named SSO profile — no long-lived access keys stored on disk.

## Repository Structure


## Incidents

Each incident follows a standard format: **Symptom → Isolation Path → Root Cause → Resolution → Prevention → Time to Resolution.**

1. SSH/SSM unreachable
2. App can't reach DynamoDB (IAM)
3. ALB 502 / unhealthy targets
4. Private subnet loses outbound
5. DNS failure
6. Disk full
7. CPU saturation
8. Security group drift detection

## Usage

```bash
terraform init
terraform plan
terraform apply

Teardown Between Sessions: 
terraform destory

## Observability Layer

After documenting the eight incidents, I built the monitoring that detects each
one automatically. The incident catalog became the monitoring spec: every
symptom I diagnosed by hand is now a detector that fires on its own. This is the
difference between reacting to failures and seeing them as they form.

### Detection mapped to each incident

| Incident | Failure | Detector |
|----------|---------|----------|
| 01 | SSH/SSM unreachable | EC2 StatusCheckFailed alarm (per instance) |
| 02 | App can't reach DynamoDB (IAM) | Surfaces in CloudTrail as AccessDenied |
| 03 | ALB 502 / unhealthy targets | ALB 5XX + UnHealthyHostCount alarms |
| 04 | Private subnet loses outbound | Synthetics canary (reachability) |
| 05 | DNS resolution failure | Synthetics canary (DNS + outbound in one check) |
| 06 | Disk full | CloudWatch agent custom metric + disk_used_percent alarm |
| 07 | CPU saturation | EC2 CPUUtilization alarm (per instance) |
| 08 | Security group drift | EventBridge rule on SG API calls -> SNS |

### Components

- **Metric alarms** (`observability.tf`) — CPU, instance status check, ALB 5XX,
  and unhealthy-host alarms, all routed to an SNS topic. Each tagged with the
  incident number it detects.
- **Custom metrics** (`disk_monitoring.tf`) — disk usage is not a default EC2
  metric, so the CloudWatch agent is installed via SSM (an install association
  runs before a configure association) and publishes disk_used_percent and
  memory to the CWAgent namespace, where an alarm watches it.
- **Config-drift detection** (`drift_detection.tf` + `cloudtrail.tf`) — an
  EventBridge rule matches security-group mutation API calls
  (Authorize/Revoke ingress/egress) and routes a formatted alert to SNS. This is
  drift caught as an event, not as a metric: the moment a rule changes, the
  change is announced. CloudTrail feeds the API events the rule matches.
- **Synthetic monitoring** (`canaries.tf`) — a CloudWatch Synthetics canary runs
  every five minutes, resolving DNS and reaching an external endpoint over HTTPS.
  If DNS breaks or outbound is severed, the canary fails and alarms — a leading
  indicator that catches incidents 04 and 05 before a user reports them.
- **Dashboard** (`dashboard.tf`) — a single CloudWatch dashboard with every
  detector on one screen: CPU, status checks, ALB errors, healthy vs. unhealthy
  hosts, request count and latency, and an alarm-state panel showing all
  detectors at once. Each widget is titled with the incident it maps to.

### Design principle

The whole layer follows one idea: map the system completely enough that
divergence from intended state is visible. Threshold alarms catch resource
exhaustion. The canary catches network and DNS failures as they happen. The
EventBridge rule catches configuration drift the instant it occurs. Together they
turn the eight incidents from things I diagnosed after the fact into things the
system reports on its own.

### Notes from the build

- The CloudWatch agent's `configure` action fails if the agent isn't installed
  first ("CloudWatch Agent not installed"). The fix is an ordering dependency:
  an `AWS-ConfigureAWSPackage` install association runs before the configure
  association, wired with `depends_on`.
- The AMI was originally pinned to `most_recent = true`, which forced instance
  replacement on every apply once AWS published a newer AL2023 image. Pinning to
  a specific AMI ID stopped the churn.
- SNS topic and subscription resources that had been removed from config but
  left in state were cleaned with `terraform state rm`, then the topic was read
  back in via a data source so the alarms could reference it without managing it.
