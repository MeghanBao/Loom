defmodule Loom.Agent do
  @moduledoc """
  Behaviour for defining AI agents in Loom.

  An agent is an autonomous unit of work — a BEAM process that accepts input
  and produces output, typically by calling an LLM or executing tools.

  ## Usage

      defmodule MyAgent do
        use Loom.Agent

        @impl true
        def run(input, opts) do
          Loom.LLM.chat("Process: \#{input}", opts)
        end
      end

  ## Options

  When using `use Loom.Agent`, you can configure defaults:

      use Loom.Agent,
        timeout: 30_000,
        max_retries: 3

  ## Callbacks

    * `run/2` - Required. Executes the agent's logic with input and options.
    * `on_error/2` - Optional. Called when the agent encounters an error.
  """

  @type result :: {:ok, term()} | {:error, term()}

  @callback run(input :: term(), opts :: keyword()) :: result()
  @callback on_error(error :: term(), input :: term()) :: :retry | :skip | :abort

  @optional_callbacks [on_error: 2]

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour Loom.Agent

      @loom_agent_opts unquote(opts)

      def __loom_agent_opts__, do: @loom_agent_opts

      def on_error(_error, _input), do: :retry

      defoverridable on_error: 2
    end
  end

  @doc """
  Executes an agent with the given input under supervision.

  The agent runs as a supervised task with retry and timeout logic.
  Emits telemetry events for observability.
  """
  @spec execute(module(), term(), keyword()) :: result()
  def execute(agent_module, input, opts \\ []) do
    agent_opts = apply(agent_module, :__loom_agent_opts__, [])
    timeout = opts[:timeout] || agent_opts[:timeout] || default_timeout()
    max_retries = opts[:max_retries] || agent_opts[:max_retries] || default_max_retries()

    metadata = %{agent: agent_module, input: input}
    start_time = System.monotonic_time()

    :telemetry.execute([:loom, :agent, :start], %{system_time: System.system_time()}, metadata)

    result = execute_with_retries(agent_module, input, opts, max_retries, timeout)

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, _} ->
        :telemetry.execute([:loom, :agent, :stop], %{duration: duration}, metadata)

      {:error, reason} ->
        :telemetry.execute(
          [:loom, :agent, :error],
          %{duration: duration},
          Map.put(metadata, :error, reason)
        )
    end

    result
  end

  defp execute_with_retries(agent_module, input, opts, retries_left, timeout) do
    task =
      Task.Supervisor.async_nolink(Loom.TaskSupervisor, fn ->
        agent_module.run(input, opts)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        {:ok, result}

      {:ok, {:error, reason}} ->
        maybe_retry(agent_module, input, opts, retries_left, timeout, reason)

      {:exit, reason} ->
        maybe_retry(agent_module, input, opts, retries_left, timeout, {:exit, reason})

      nil ->
        maybe_retry(agent_module, input, opts, retries_left, timeout, :timeout)
    end
  end

  defp maybe_retry(agent_module, input, opts, retries_left, timeout, reason) do
    if retries_left > 0 do
      action =
        if function_exported?(agent_module, :on_error, 2) do
          agent_module.on_error(reason, input)
        else
          :retry
        end

      case action do
        :retry -> execute_with_retries(agent_module, input, opts, retries_left - 1, timeout)
        :skip -> {:ok, :skipped}
        :abort -> {:error, reason}
      end
    else
      {:error, reason}
    end
  end

  defp default_timeout do
    Application.get_env(:loom, :agent_timeout, 30_000)
  end

  defp default_max_retries do
    Application.get_env(:loom, :agent_max_retries, 3)
  end
end
