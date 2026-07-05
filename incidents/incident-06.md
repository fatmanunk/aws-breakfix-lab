# Incident 06 — Disk Full / Resource Exhaustion

## Symptom
Services began failing to start and write. Attempts to write files returned
"No space left on device." The instance was running and reachable; failures were
write-related.

## Isolation Path
1. Write failures pointed at a shared resource. Checked disk with df -h (all
   mounts, not just root).
2. df -h revealed the mount layout: root (/dev/nvme0n1p1) was 30G at 15%, but /tmp
   was a separate tmpfs mount of only 459M. An initial filler written to /tmp
   filled that small RAM-backed mount instantly while root stayed nearly empty -
   a "disk full" on one mount while another had 26G free.
3. Redirected the fill to /var/tmp (confirmed on the root filesystem, not a
   separate mount) to exhaust the root disk.
4. du -sh identified /var/tmp/filler as the consumer of root space. Root cause
   located.

## Root Cause
A large file (/var/tmp/filler) consumed the root filesystem. With root full, no
service could write pid files, logs, or temp data. Nothing was misconfigured -
a capacity failure, the system operating as designed with a finite resource
exhausted. The initial confusion (filling /tmp, a 459M tmpfs, rather than the 30G
root) underscored that filesystems are per-mount, not one pool.

## Resolution
Removed the offending file (sudo rm /var/tmp/filler). Root usage returned to
baseline (~15%). Services recovered: nginx restarted and file writes succeeded.
OS-level operational fix - disk contents are runtime state, not IaC-managed.

## Prevention
- Log rotation (logrotate) to cap log growth, the most common real cause.
- CloudWatch disk-utilization alarm (requires the CloudWatch agent for disk
  metrics) to alert before capacity is reached.
- Separate volume for application/temp data so a runaway consumer cannot fill the
  root filesystem and take down system services.
- Monitor directory growth to catch slow fills before the ceiling.

## Diagnostic Note
Disk-full symptoms are indirect: services fail to start, logs stop, writes error
- the disk does not announce itself. A cluster of write failures is the
fingerprint; check df -h first.

Filesystems are per-mount, not one pool. /tmp here was a separate 459M tmpfs, so
a fill there reported "no space" while the 30G root sat at 15%. df -h showing all
mounts is what exposes this - a full mount is not the same as a full disk. Verify
which filesystem is actually full before acting.

The canonical triage is df -> du: df confirms the disk is full and identifies the
specific mount; du drills from top-level directories to the consumer, sorted by
size. "No space left on device" is definitive, but presenting symptoms are
usually one step removed.

## Time to Resolution
~X minutes.
