defmodule Loom.Application do
  @moduledoc """
  OTP Application for Loom.

  Starts the supervision tree including the agent registry,
  scheduler, and runtime components.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Agent registry for name-based lookup
      {Registry, keys: :unique, name: Loom.Agent.Registry},

      # Dynamic supervisor for agent task execution
      {DynamicSupervisor, strategy: :one_for_one, name: Loom.Agent.Pool},

      # Task supervisor for workflow step execution
      {Task.Supervisor, name: Loom.TaskSupervisor},

      # Workflow scheduler
      Loom.Scheduler,

      # Runtime node manager
      Loom.Runtime.NodeManager,

      # Telemetry setup
      Loom.Telemetry.Metrics
    ]

    opts = [strategy: :one_for_one, name: Loom.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
