# Incident 03 — ALB 502 / Unhealthy Target

## Symptom
One target showed unhealthy in the target group (Target.FailedHealthChecks)
while the other served traffic normally. Requests routed to the affected target
during the transition would return 502. The EC2 instance was still running.
CloudWatch unhealthy-host alarm fired.

## Isolation Path
1. Checked target health - one target unhealthy (i-0758948ac0e1696ee), reason
   Target.FailedHealthChecks. Identified the specific instance.
2. Confirmed instance state = running (ruled out instance/infrastructure
   failure). The problem was above the instance layer.
3. Opened an SSM session and checked the application process:
   systemctl status nginx = inactive (dead), deactivated successfully at
   2026-07-04 17:34:51 UTC. Box up, app down. Clean stop, not a crash.
4. Confirmed the health-check path was correct (ruled out health-check
   misconfiguration - genuine app failure, not a false negative).

## Root Cause
The nginx process was stopped on one instance. The EC2 instance remained running,
but with the web server down it could not answer health checks or serve traffic,
so the ALB marked it unhealthy and returned 502s for requests routed to it.

## Resolution
Restarted nginx on the affected instance (sudo systemctl start nginx). Operational
fix, not a Terraform drift correction - Terraform manages infrastructure state,
not the runtime state of processes on the instance. Health checks passed within
~30 seconds and the target returned to healthy.

## Prevention
- CloudWatch unhealthy-host alarm (already in place) fired correctly and gave
  early detection.
- systemd restart policy on nginx (Restart=always) to auto-recover the process.
- Auto scaling group to replace persistently unhealthy instances.

## Diagnostic Note
"Instance running" and "application running" are different states. A running EC2
instance with a dead application is a common production failure. Descend the stack
in order: target group (app-layer health) -> instance state (infrastructure) ->
process status (application). Confirming infrastructure is healthy before logging
into the box avoids diagnosing the wrong layer. Not every fix is a terraform apply
- runtime process failures are resolved on the instance, not in the IaC.

## Time to Resolution
~X minutes.
