# Incident 04 — Private Subnet Loses Outbound Internet

## Symptom
Both instances in the private subnets lost SSM connectivity (PingStatus:
ConnectionLost) and could not reach the internet. SSM sessions would not start
("not connected"). Instances were running; NAT gateway was available.

## Isolation Path
1. Both instances showed ConnectionLost simultaneously - a shared cause, not an
   individual instance fault. Pointed at a path common to both.
2. Confirmed both instances running (ruled out instance failure).
3. Confirmed NAT gateway state = available (ruled out NAT failure).
4. terraform plan compared config against live infrastructure and showed a single
   change: the 0.0.0.0/0 -> NAT route missing from the private route table
   (rtb-070ab26cdf334ace7). Root cause identified precisely.

## Root Cause
The default route (0.0.0.0/0 -> NAT gateway) was removed from the private route
table. Both private subnets associate with this single table, so removing the
one route severed outbound internet for every instance behind it at once. The
SSM agents lost their outbound path to the SSM endpoints and dropped to
ConnectionLost.

## Resolution
Restored the route via terraform apply (drift correction). terraform plan
identified exactly one change - re-adding the missing NAT route. After apply,
outbound was confirmed (curl returned successfully) and both SSM agents
reconnected; sessions started normally.

## Prevention
- Terraform as source of truth; terraform plan surfaces route-table changes as
  drift and shows blast radius precisely.
- Restrict route-table modification permissions in IAM - route changes have high
  blast radius (all subnets on the table, not just one instance).
- Synthetic outbound check or NAT/route CloudWatch alerting to detect egress loss
  proactively rather than on failed connection.

## Diagnostic Note
Route-table changes have a large blast radius. A single deleted route took out
outbound for every node in both private subnets simultaneously, because both
subnets share one route table. This is distinct from a security-group change,
which affects only the instances on that SG. When multiple instances fail at
once, suspect a shared dependency (route table, NAT, shared SG) before an
individual instance. terraform plan, comparing config against live state, is the
authoritative diagnosis - it showed the single divergence directly and resolved a
conflicting manual SG-egress read.

## Time to Resolution
~X minutes.
