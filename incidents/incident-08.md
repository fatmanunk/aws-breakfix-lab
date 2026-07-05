# Incident 08 — Security Group Drift Detection

## Symptom
None functionally. The application continued working, health checks passed, and
no alarm fired. The DB security group had been modified to allow inbound traffic
from 0.0.0.0/0, publicly exposing the database tier - but this produced no
runtime symptom. The exposure was silent.

## Isolation Path
1. No outage, no alarm, no user-visible failure - so detection required a
   proactive audit rather than reactive alerting.
2. terraform plan compared the declared configuration against live infrastructure
   and flagged drift: an ingress rule present in the environment but absent from
   the code. Terraform proposed removing it.
3. Read the drift - the undeclared rule opened the DB port to 0.0.0.0/0,
   unauthorized public exposure of the database tier.
4. Confirmed against the live SG with describe-security-groups: the 0.0.0.0/0
   ingress rule was present on breakfix-db-sg.

## Root Cause
An unauthorized manual change added a 0.0.0.0/0 ingress rule to the DB security
group, exposing the database tier to the internet. The change bypassed the IaC
pipeline (made directly in the console), so it existed in the environment but not
in the Terraform configuration. Because it caused no functional failure, it was
undetectable by health monitoring - only a configuration audit surfaced it.

## Resolution
terraform apply removed the unauthorized rule, re-converging the DB SG on its
declared scoped state (ingress from the App SG only). Verified via
describe-security-groups that the 0.0.0.0/0 rule was gone.

## Prevention
- Scheduled terraform plan (e.g. in CI) as a continuous drift/audit control to
  detect unauthorized changes automatically.
- Restrict security-group modification permissions in IAM so changes cannot be
  made outside the pipeline.
- AWS Config rules to flag security groups open to 0.0.0.0/0 on sensitive ports.
- Service control policies to prevent direct console modification of protected
  resources.

## Diagnostic Note
Security drift has no runtime symptom - it exposes rather than breaks, so it
cannot be caught by waiting for failure. Detection requires proactive auditing
against a known-good declared state. terraform plan functions as a security audit
tool: when plan proposes removing a rule that was never declared in code, that is
the signature of an unauthorized out-of-band change. The direction is the tell -
plan removing something means reality contains what the code does not, i.e.
someone modified infrastructure outside the pipeline. IaC closes the loop:
declare the correct posture, detect deviation with plan, remediate with apply.

## Time to Resolution
~X minutes.
