# Incident 02 — Instance Role Loses DynamoDB Access (IAM)

## Symptom
The instance role's DynamoDB permissions were removed. The application running
on the EC2 instances would be denied all DynamoDB operations (reads and writes),
while the network path to DynamoDB remained intact. Instances running normally.

## Isolation Path
1. Scanned the table via the admin (terraform) profile: returned Count 0 with no
   error. This confirmed the table existed and was reachable, but did NOT test the
   instance role — the admin profile has full access and bypasses the instance
   role entirely. Verifying one way answered a different question than intended.
2. Verified the actual break from a second angle: inspected the role's inline
   policies directly.
   aws iam list-role-policies --role-name breakfix-app-role
   Result: empty. The breakfix-dynamo-access policy was absent.
3. Confirmed the network path was never the issue — the DynamoDB VPC endpoint
   remained present and available.

## Root Cause
The entire breakfix-dynamo-access inline policy was deleted from the instance
role (breakfix-app-role). With no DynamoDB permissions attached, the app's calls
from the instance would be denied. The admin profile's successful scan was
misleading — it does not use the instance role.

## Resolution
Restored the policy via terraform apply (drift correction). terraform plan
identified the missing aws_iam_role_policy.dynamo resource and showed it being
re-added. After apply, list-role-policies showed breakfix-dynamo-access back on
the role.

## Prevention
- Terraform as source of truth; terraform plan surfaces IAM policy deletion as
  drift — permission changes are otherwise silent until an action is attempted.
- Restrict IAM policy-modification permissions so scoped roles cannot be altered
  by unprivileged identities.
- CloudTrail alerting on IAM policy-deletion events to catch removal in real time.

## Diagnostic Note
Verify services more than one way. A scan through the admin profile returned a
clean result and told me nothing about the instance role break, because the admin
profile bypasses that role. Confirming the actual state required checking the role
directly with list-role-policies. One verification method answered a different
question than the one being asked; a second method confirmed the real state.

Additional: terraform plan reads Terraform's own reality (the state file) compared
against live infrastructure, then shows the drift precisely. terraform apply
returns the environment to the declared ideal state. The caveat at scale: console-
created resources never written into the .tf files appear as drift to destroy, so
apply-to-restore is only safe when all changes flow through code (or console
resources are imported into state first).

## Time to Resolution
~X minutes.
