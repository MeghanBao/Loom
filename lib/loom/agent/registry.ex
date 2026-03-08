defmodule Loom.Agent.AgentRegistry do
  @moduledoc """
  Agent registry for name-based lookup and lifecycle management.

  Provides a way to register agent modules by name for dynamic
  discovery and invocation within workflows.
  """

  @registry Loom.Agent.Registry

  @doc """
  Registers an agent module under a given name.

  ## Examples

      :ok = Loom.Agent.AgentRegistry.register(:researcher, ResearchAgent)
  """
  @spec register(atom(), module()) :: :ok | {:error, :already_registered}
  def register(name, agent_module) when is_atom(name) and is_atom(agent_module) do
    case Registry.register(@registry, name, agent_module) do
      {:ok, _pid} -> :ok
      {:error, {:already_registered, _}} -> {:error, :already_registered}
    end
  end

  @doc """
  Looks up an agent module by name.

  ## Examples

      {:ok, ResearchAgent} = Loom.Agent.AgentRegistry.lookup(:researcher)
  """
  @spec lookup(atom()) :: {:ok, module()} | {:error, :not_found}
  def lookup(name) when is_atom(name) do
    case Registry.lookup(@registry, name) do
      [{_pid, module}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered agent names and their modules.
  """
  @spec list() :: [{atom(), module()}]
  def list do
    Registry.select(@registry, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
  end
end
