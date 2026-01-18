# gen_registry ETS Race Condition

Minimal reproduction of a race condition in `gen_registry` where `lookup_or_start/3` can return PIDs of dead processes.

## The Problem

`lookup_or_start/3` first checks ETS directly (bypassing the GenServer). When a worker stops itself, the EXIT message is sent to the registry's mailbox but may not yet be processed. During this window, lookups return a stale PID pointing to a dead process.

### Real-World Scenario

This bug manifests in systems where:

1. An actor manages client connections
2. When the last client disconnects, the actor stops itself
3. A new client immediately tries to connect to the same actor

```
Timeline:
1. TokenActor exists with 1 WebSocket connection, registered in ETS
2. Client disconnects → actor receives message, calls {:stop, :normal, state}
3. EXIT signal sent to registry's mailbox (NOT yet processed)
4. New client connects, calls lookup_or_start(registry, token_id, ...)
5. lookup phase reads from ETS → finds stale entry, returns dead PID
6. Caller does GenServer.call(pid, :get_info) → ** (EXIT) :noproc **
7. Later: registry processes EXIT, removes ETS entry (too late)
```

## Reproduction

```bash
mix deps.get
mix test
```

Output:

```
:noproc crashes due to stale PIDs: ~980/1000
```

~98% reproduction rate.

## Suggested Fix

Before returning a PID from lookup, verify the process is still alive:

```elixir
def lookup(module, id) do
  case :ets.lookup(table, id) do
    [{^id, pid}] ->
      if Process.alive?(pid) do
        {:ok, pid}
      else
        # Stale entry - EXIT message in flight, clean up proactively
        :ets.delete(table, id)
        {:error, :not_found}
      end
    [] ->
      {:error, :not_found}
  end
end
```

## Environment

- Elixir: 1.19
- gen_registry: 1.3.0
