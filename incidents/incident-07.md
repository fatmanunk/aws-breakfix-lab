# Incident 07 — CPU Saturation

## Symptom
Application responses became sluggish; latency climbed while no hard errors
occurred. The instance remained reachable, disk and network were fine. The
system degraded rather than broke. CloudWatch high-CPU alarm fired.

## Isolation Path
1. App slow but not erroring, instance reachable, disk and network healthy -
   pointed at compute capacity rather than a hard failure.
2. uptime showed load average well above the core count - CPU oversubscribed
   (load exceeding available cores means more work queued than can run).
3. top / ps -eo pid,ppid,cmd,%cpu --sort=-%cpu identified the consuming processes
   at ~100% CPU each, with PIDs.
4. nproc confirmed 2 vCPUs, so the elevated load average was interpreted correctly
   as full saturation plus queued work.

## Root Cause
Runaway processes consumed all available CPU, saturating both vCPUs on the
t3.micro. Nothing was misconfigured or broken - a capacity failure. With CPU
maxed, every operation slowed because work queued behind the saturating
processes, producing degradation without outright errors.

## Resolution
Terminated the offending processes (kill / pkill by name or PID). Load average
returned to baseline and application responsiveness recovered. OS-level
operational fix - runtime process state, not IaC-managed.

## Prevention
- CloudWatch high-CPU alarm (already in place, threshold 80%) fired and gave
  early detection of the degradation.
- Auto scaling based on CPU to add capacity under legitimate load.
- Process-level resource limits (cgroups / systemd CPUQuota) to cap what a single
  process can consume.
- Distinguish legitimate load (needs scaling) from a runaway/bug (needs a fix)
  before choosing the response.

## Diagnostic Note
CPU saturation degrades rather than breaks: slow responses, climbing latency,
rising load average, but no hard error. "Slow, not broken" is the compute-capacity
signature. The definitive signal is load average relative to core count - load
must be read against nproc, since a load of 4 is healthy on 8 cores and
catastrophic on 2. The triage is load-average -> top/ps: uptime confirms
saturation relative to cores, top or ps --sort=-%cpu identifies the consumer with
PIDs. Parallel to the df -> du sequence for disk: one command confirms and
quantifies the exhaustion, the next locates what caused it.

## Time to Resolution
~X minutes.
