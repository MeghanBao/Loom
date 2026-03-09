defmodule Loom.Telemetry.Metrics do
  @moduledoc """
  Telemetry event definitions and default handlers for Loom.

  Loom emits the following telemetry events:

  ## Agent Events

    * `[:loom, :agent, :start]` — Agent execution started
    * `[:loom, :agent, :stop]` — Agent execution completed successfully
    * `[:loom, :agent, :error]` — Agent execution failed

  ## Workflow Events

    * `[:loom, :workflow, :start]` — Workflow execution started
    * `[:loom, :workflow, :stop]` — Workflow execution completed
    * `[:loom, :workflow, :error]` — Workflow execution failed

  ## Step Events

    * `[:loom, :step, :start]` — Individual step started
    * `[:loom, :step, :stop]` — Individual step completed
    * `[:loom, :step, :error]` — Individual step failed

  ## Usage

  Attach your own handlers:

      :telemetry.attach("my-handler", [:loom, :agent, :stop], &MyModule.handle_event/4, nil)

  Or use the built-in logging handler:

      Loom.Telemetry.Metrics.attach_default_handlers()
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    attach_default_handlers()
    {:ok, %{}}
  end

  @doc """
  Attaches default logging handlers for all Loom telemetry events.
  """
  @spec attach_default_handlers() :: :ok
  def attach_default_handlers do
    events = [
      [:loom, :agent, :start],
      [:loom, :agent, :stop],
      [:loom, :agent, :error],
      [:loom, :workflow, :start],
      [:loom, :workflow, :stop],
      [:loom, :workflow, :error],
      [:loom, :step, :start],
      [:loom, :step, :stop],
      [:loom, :step, :error]
    ]

    :telemetry.attach_many(
      "loom-default-logger",
      events,
      &__MODULE__.handle_event/4,
      nil
    )

    :ok
  end

  @doc false
  def handle_event([:loom, component, :start], measurements, metadata, _config) do
    Logger.debug("[Loom] #{component} started",
      component: component,
      metadata: metadata,
      time: measurements[:system_time]
    )
  end

  def handle_event([:loom, component, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

    Logger.info("[Loom] #{component} completed in #{duration_ms}ms",
      component: component,
      duration_ms: duration_ms,
      metadata: metadata
    )
  end

  def handle_event([:loom, component, :error], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

    Logger.error(
      "[Loom] #{component} failed after #{duration_ms}ms: #{inspect(metadata[:error])}",
      component: component,
      duration_ms: duration_ms,
      error: metadata[:error]
    )
  end
end
