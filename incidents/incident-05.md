# Incident 05 — DNS Resolution Failure

## Symptom
Instance could not reach external services by hostname (curl to aws.amazon.com
failed with "could not resolve host"). Connections by IP address succeeded.
Routing and outbound were intact; only name resolution failed.

## Isolation Path
1. curl by hostname failed with a resolution error, not a connection error.
2. curl/ping by IP succeeded - routing and outbound were fine. Ruled out NAT,
   route table, and security group (the connectivity causes from Incidents 01
   and 04).
3. getent hosts aws.amazon.com returned nothing - the system resolver could not
   resolve the name, confirming a resolution failure rather than a connectivity
   failure. (nslookup/dig were not installed on the Amazon Linux 2023 minimal
   AMI; getent uses the system resolver and required no extra package.)
4. Inspected /etc/resolv.conf: nameserver set to an unreachable address
   (10.255.255.255). Root cause identified.

## Root Cause
The instance's resolver configuration (/etc/resolv.conf) was pointed at a
non-functional DNS server. With no working resolver, hostname lookups failed
while IP-based connectivity remained fully functional, because DNS operates
above the routing and security-group layers.

## Resolution
Restored /etc/resolv.conf to the working resolver (OS-level fix, not a Terraform
drift correction - resolv.conf is instance runtime state, not IaC-managed).
Hostname resolution confirmed restored: getent hosts aws.amazon.com returned the
address and curl by hostname connected.

## Prevention
- On Amazon Linux, resolv.conf is system-managed and repopulates on network
  restart/reboot - a reboot is an alternate recovery.
- Restrict OS-level modification access; monitor for resolver config changes.
- Synthetic DNS check (resolve a known hostname on a schedule) to detect
  resolution failure proactively.

## Diagnostic Note
Name-based access failing while IP-based access succeeds is the signature of a
DNS problem. If both fail, suspect routing/connectivity; if only hostname
resolution fails, suspect DNS. DNS failures masquerade as total outages until you
test by IP - testing by IP is what separates a resolution failure from a network
failure. DNS sits above the routing and security-group layers, so the network can
be perfectly healthy while every hostname lookup fails.

Tooling note: nslookup and dig were absent on the minimal AMI (bind-utils not
installed). getent hosts resolves through the system resolver with no added
package, making it a reliable fallback for confirming resolution inside a
constrained environment.

## Time to Resolution
~X minutes.
