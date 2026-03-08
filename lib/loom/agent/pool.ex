defmodule Loom.Agent.Pool do
  @moduledoc """
  Agent execution pool using DynamicSupervisor.

  Manages concurrent agent execution with configurable concurrency limits.
  Each agent task runs under supervision for fault tolerance.
  """

  @pool Loom.Agent.Pool

  @doc """
  Starts an agent task under the dynamic supervisor.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start_task(module(), term(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_task(agent_module, input, opts \\ []) do
    spec = {Task, fn -> Loom.Agent.execute(agent_module, input, opts) end}

    case DynamicSupervisor.start_child(@pool, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the number of currently running agent tasks.
  """
  @spec active_count() :: non_neg_integer()
  def active_count do
    DynamicSupervisor.count_children(@pool).active
  end
end
