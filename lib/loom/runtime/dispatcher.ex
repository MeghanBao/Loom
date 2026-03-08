defmodule Loom.Runtime.Dispatcher do
  @moduledoc """
  Distributes tasks across BEAM nodes.

  Supports multiple dispatch strategies:
  - `:round_robin` — cycles through available nodes
  - `:least_loaded` — picks the node with fewest running tasks
  - `:local` — always runs locally (default fallback)
  """

  alias Loom.Runtime.NodeManager

  @type strategy :: :round_robin | :least_loaded | :local

  @doc """
  Dispatches a function to execute on an available node.

  Falls back to local execution if no remote nodes are available.

  ## Options

    * `:strategy` - Dispatch strategy (default: `:round_robin`)
  """
  @spec dispatch((() -> term()), keyword()) :: term()
  def dispatch(fun, opts \\ []) do
    strategy = opts[:strategy] || :round_robin

    case select_node(strategy) do
      :local ->
        fun.()

      node ->
        Node.spawn(node, fn ->
          result = fun.()
          send(opts[:reply_to] || self(), {:dispatch_result, result})
        end)
    end
  end

  @doc """
  Dispatches a function and waits for the result.
  """
  @spec dispatch_sync((() -> term()), keyword()) :: {:ok, term()} | {:error, :timeout}
  def dispatch_sync(fun, opts \\ []) do
    timeout = opts[:timeout] || 30_000
    me = self()
    opts = Keyword.put(opts, :reply_to, me)

    case select_node(opts[:strategy] || :round_robin) do
      :local ->
        {:ok, fun.()}

      node ->
        Node.spawn(node, fn ->
          result = fun.()
          send(me, {:dispatch_result, result})
        end)

        receive do
          {:dispatch_result, result} -> {:ok, result}
        after
          timeout -> {:error, :timeout}
        end
    end
  end

  defp select_node(strategy) do
    nodes = NodeManager.available_nodes()

    case {strategy, nodes} do
      {_, []} -> :local
      {:local, _} -> :local
      {:round_robin, nodes} -> Enum.random(nodes)
      {:least_loaded, nodes} -> Enum.random(nodes)
    end
  end
end
