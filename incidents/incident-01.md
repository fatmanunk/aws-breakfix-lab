# Incident 01 — SSH/SSM Unreachable

## Symptom
Instances became unreachable for new SSM connections. Existing Session Manager
sessions remained connected (persistent tunnels), which initially masked the
failure. New session attempts and agent re-registration would fail. Instances
were still running.

## Isolation Path
1. Confirmed instance state = running via
   `aws ec2 describe-instances --instance-ids <id> --query "Reservations[].Instances[].State.Name"`.
   Ruled out instance failure.
2. Noted existing SSM session still connected — recognized this as a persistent
   connection, not proof of a healthy network path. Did not treat it as evidence
   the instance was fine.
3. Tested the outbound path the SSM agent depends on, from inside the instance:
   `curl -v https://ssm.us-east-1.amazonaws.com --max-time 10`.
   Result: 0 connections / timeout. Confirmed the instance could not reach the
   SSM service endpoint outbound.
4. Checked the App security group egress rules:
   `aws ec2 describe-security-groups --group-ids sg-06527dd924e115368 --query "SecurityGroups[].IpPermissionsEgress"`.
   Result: empty. No outbound path existed.

## Root Cause
The App security group's egress rule was removed. The SSM agent maintains its
connection by reaching outbound over HTTPS (443) to the ssm, ssmmessages, and
ec2messages endpoints. With egress removed, the agent could not phone home or
re-establish a connection. Existing sessions persisted only because they were
already-open tunnels.

## Resolution
Restored the egress rule via `terraform apply` (drift correction — the rule was
removed manually in the console, creating divergence between the Terraform state
and live infrastructure). Initial verification via curl from the existing session
still failed (stale session state). Reconnected with a fresh SSM session and
confirmed outbound restored: `curl -v https://aws.amazon.com` returned HTTP 200,
and the SSM endpoint was reachable. Fix confirmed.

## Prevention
- Terraform as source of truth; `terraform plan` surfaces unauthorized security
  group changes as drift.
- Restrict security group modification permissions in IAM so egress rules cannot
  be removed by unprivileged identities.
- CloudWatch alarm on SSM agent ping status to alert on connection loss rather
  than discovering it on the next connection attempt.

## Diagnostic Note
Persistent SSM sessions do not reflect live changes to the network path, in
either direction:

- Before the fix, an existing session stayed connected after egress was cut,
  making a severed path look healthy. Verifying the actual outbound path with
  curl, not trusting the live session, surfaced the real cause.

- After the fix, curl from that same pre-existing session still returned 0
  connections, making a correct restore look like a failed one. Only a fresh
  session confirmed the fix (HTTP 200). The remediation was right; the stale
  session was the wrong instrument to verify it.

Lesson: validate network changes from a new session, and confirm the path
independently (e.g. curl to a general endpoint like aws.amazon.com) before
trusting or doubting a fix.

## Time to Resolution
~5 minutes from symptom to confirmed restore.
