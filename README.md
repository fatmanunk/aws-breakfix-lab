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
