# gen_registry ETS Race Condition

Minimal reproduction of a race condition in `gen_registry` where `lookup_or_start/3` can return PIDs of dead processes.

## The Problem

`lookup_or_start/3` first checks ETS directly (bypassing the GenServer). When a worker stops itself, the EXIT message is sent to the registry's mailbox but may not yet be processed. During this window, lookups return a stale PID pointing to a dead process.

```bash
mix deps.get
mix test
```

Output:

```
:noproc crashes due to stale PIDs: ~980/1000
```

~98% reproduction rate.
