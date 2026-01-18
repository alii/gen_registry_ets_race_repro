defmodule RaceConditionTest do
  use ExUnit.Case

  defmodule Worker do
    use GenServer

    def start_link(id), do: GenServer.start_link(__MODULE__, id)
    def get_info(pid), do: GenServer.call(pid, :get_info)
    def disconnect(pid), do: GenServer.cast(pid, :disconnect)

    def init(id), do: {:ok, %{id: id, connections: 1}}

    def handle_call(:get_info, _from, state) do
      {:reply, {:ok, state.id}, state}
    end

    def handle_cast(:disconnect, state) do
      case state.connections - 1 do
        0 -> {:stop, :normal, state}
        n -> {:noreply, %{state | connections: n}}
      end
    end
  end

  setup do
    {:ok, _} = GenRegistry.start_link(Worker, name: Worker)
    on_exit(fn -> catch_exit(GenServer.stop(Worker)) end)
    :ok
  end

  test "lookup_or_start returns stale PID when worker stops itself" do
    # Real-world scenario:
    # 1. Worker exists with 1 connection
    # 2. Connection disconnects → worker stops itself
    # 3. EXIT signal sent to registry's mailbox (monitor fired)
    # 4. New connection calls lookup_or_start → reads ETS directly, finds stale PID
    #    (registry hasn't processed the EXIT from its mailbox yet)
    # 5. Tries to call get_info → :noproc crash

    crashes =
      for i <- 1..1000 do
        id = :"worker_#{i}"

        # Start a worker (simulates: client connects, actor starts)
        {:ok, pid} = GenRegistry.lookup_or_start(Worker, id, [id])

        # Disconnect - worker stops itself (simulates: last client disconnects)
        Worker.disconnect(pid)

        # New client (separate process) immediately tries to connect
        task = Task.async(fn ->
          case GenRegistry.lookup_or_start(Worker, id, [id]) do
            {:ok, new_pid} ->
              # Try to use it - this crashes in production
              try do
                Worker.get_info(new_pid)
                false
              catch
                :exit, _ -> true
              end

            {:error, _} ->
              false
          end
        end)

        Task.await(task)
      end

    crash_count = Enum.count(crashes, & &1)

    IO.puts("\n\n:noproc crashes due to stale PIDs: #{crash_count}/1000")
    assert crash_count > 0, "Expected to catch race condition at least once"
  end
end
