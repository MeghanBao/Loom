defmodule Loom.Runtime.NodeManager do
  @moduledoc """
  Manages connected BEAM nodes for distributed execution.

  Tracks node health, monitors connections, and provides
  an API for querying available nodes for task distribution.
  """

  use GenServer

  defstruct nodes: %{}, check_interval: 10_000

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns all connected nodes with their status.
  """
  @spec list_nodes() :: [%{node: node(), status: :healthy | :unhealthy, last_seen: DateTime.t()}]
  def list_nodes do
    GenServer.call(__MODULE__, :list_nodes)
  end

  @doc """
  Returns only healthy, available nodes.
  """
  @spec available_nodes() :: [node()]
  def available_nodes do
    GenServer.call(__MODULE__, :available_nodes)
  end

  @doc """
  Manually adds a node to monitor.
  """
  @spec add_node(node()) :: :ok
  def add_node(node_name) do
    GenServer.cast(__MODULE__, {:add_node, node_name})
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    interval = opts[:check_interval] || 10_000
    schedule_health_check(interval)

    # Monitor node connection/disconnection
    :net_kernel.monitor_nodes(true)

    # Track currently connected nodes
    nodes =
      Node.list()
      |> Map.new(fn n -> {n, %{status: :healthy, last_seen: DateTime.utc_now()}} end)

    {:ok, %__MODULE__{nodes: nodes, check_interval: interval}}
  end

  @impl true
  def handle_call(:list_nodes, _from, state) do
    result =
      Enum.map(state.nodes, fn {node, info} ->
        Map.put(info, :node, node)
      end)

    {:reply, result, state}
  end

  def handle_call(:available_nodes, _from, state) do
    available =
      state.nodes
      |> Enum.filter(fn {_node, info} -> info.status == :healthy end)
      |> Enum.map(fn {node, _} -> node end)

    {:reply, available, state}
  end

  @impl true
  def handle_cast({:add_node, node_name}, state) do
    nodes = Map.put_new(state.nodes, node_name, %{status: :healthy, last_seen: DateTime.utc_now()})
    {:noreply, %{state | nodes: nodes}}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    nodes = Map.put(state.nodes, node, %{status: :healthy, last_seen: DateTime.utc_now()})
    {:noreply, %{state | nodes: nodes}}
  end

  def handle_info({:nodedown, node}, state) do
    nodes = Map.update(state.nodes, node, %{status: :unhealthy, last_seen: DateTime.utc_now()}, fn info ->
      %{info | status: :unhealthy}
    end)
    {:noreply, %{state | nodes: nodes}}
  end

  def handle_info(:health_check, state) do
    nodes =
      Map.new(state.nodes, fn {node, info} ->
        status = if Node.ping(node) == :pong, do: :healthy, else: :unhealthy
        {node, %{info | status: status, last_seen: DateTime.utc_now()}}
      end)

    schedule_health_check(state.check_interval)
    {:noreply, %{state | nodes: nodes}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end
end
