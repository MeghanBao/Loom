defmodule Loom.Scheduler do
  @moduledoc """
  Workflow scheduler managing execution queue and concurrency.

  The scheduler accepts workflow execution requests and manages them
  with configurable concurrency limits. Workflows are queued and
  dispatched as capacity becomes available.
  """

  use GenServer

  alias Loom.Scheduler.Queue
  alias Loom.Workflow.Executor

  defstruct queue: Queue.new(),
            running: %{},
            max_concurrent: 10,
            waiters: %{}

  # --- Client API ---

  @doc """
  Starts the scheduler process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a workflow synchronously, blocking until completion.
  """
  @spec execute_sync(Loom.Workflow.Graph.t(), term(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def execute_sync(workflow, input, opts \\ []) do
    timeout = opts[:timeout] || 60_000
    GenServer.call(__MODULE__, {:execute, workflow, input, opts}, timeout)
  end

  @doc """
  Executes a workflow asynchronously, returning a reference.
  """
  @spec execute_async(Loom.Workflow.Graph.t(), term(), keyword()) :: {:ok, reference()}
  def execute_async(workflow, input, opts \\ []) do
    ref = make_ref()
    GenServer.cast(__MODULE__, {:execute_async, ref, self(), workflow, input, opts})
    {:ok, ref}
  end

  @doc """
  Awaits the result of an async workflow execution.
  """
  @spec await(reference(), timeout()) :: {:ok, map()} | {:error, term()}
  def await(ref, timeout \\ 60_000) do
    receive do
      {:loom_result, ^ref, result} -> result
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Returns the current scheduler status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    max = opts[:max_concurrent] || Application.get_env(:loom, :max_concurrent_workflows, 10)
    {:ok, %__MODULE__{max_concurrent: max}}
  end

  @impl true
  def handle_call({:execute, workflow, input, opts}, from, state) do
    state = enqueue_and_dispatch(state, workflow, input, opts, {:sync, from})
    {:noreply, state}
  end

  def handle_call(:status, _from, state) do
    status = %{
      queued: Queue.size(state.queue),
      running: map_size(state.running),
      max_concurrent: state.max_concurrent
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:execute_async, ref, caller, workflow, input, opts}, state) do
    state = enqueue_and_dispatch(state, workflow, input, opts, {:async, caller, ref})
    {:noreply, state}
  end

  @impl true
  def handle_info({:task_done, task_ref, result}, state) do
    case Map.pop(state.running, task_ref) do
      {nil, _} ->
        {:noreply, state}

      {waiter, running} ->
        reply_to_waiter(waiter, result)
        state = %{state | running: running}
        state = dispatch_next(state)
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.running, ref) do
      {nil, _} ->
        {:noreply, state}

      {waiter, running} ->
        reply_to_waiter(waiter, {:error, {:crashed, reason}})
        state = %{state | running: running}
        state = dispatch_next(state)
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- Internal ---

  defp enqueue_and_dispatch(state, workflow, input, opts, waiter) do
    item = %{workflow: workflow, input: input, opts: opts, waiter: waiter}
    state = %{state | queue: Queue.enqueue(state.queue, item)}
    dispatch_next(state)
  end

  defp dispatch_next(state) do
    if map_size(state.running) < state.max_concurrent do
      case Queue.dequeue(state.queue) do
        {:empty, _} ->
          state

        {{:value, item}, queue} ->
          scheduler = self()
          task_ref = make_ref()

          _pid =
            spawn(fn ->
              _ref = Process.monitor(self())
              result = Executor.execute(item.workflow, item.input, item.opts)
              send(scheduler, {:task_done, task_ref, result})
            end)

          running = Map.put(state.running, task_ref, item.waiter)
          %{state | queue: queue, running: running}
      end
    else
      state
    end
  end

  defp reply_to_waiter({:sync, from}, result), do: GenServer.reply(from, result)
  defp reply_to_waiter({:async, caller, ref}, result), do: send(caller, {:loom_result, ref, result})
end
