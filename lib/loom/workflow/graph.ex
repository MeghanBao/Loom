defmodule Loom.Workflow.Graph do
  @moduledoc """
  DAG-based workflow definition.

  A workflow is a directed acyclic graph where each node is an agent step
  and edges represent dependencies between steps.

  ## Example

      workflow =
        Loom.Workflow.new("research_pipeline")
        |> Loom.Workflow.step(:research, ResearchAgent)
        |> Loom.Workflow.step(:analyze, AnalyzeAgent, deps: [:research])
        |> Loom.Workflow.step(:summarize, SummaryAgent, deps: [:analyze])

  ## Parallel Execution

  Steps with no dependencies (or whose dependencies are met) run in parallel:

      workflow =
        Loom.Workflow.new("parallel_search")
        |> Loom.Workflow.step(:web_search, WebSearchAgent)
        |> Loom.Workflow.step(:wiki_search, WikiSearchAgent)
        |> Loom.Workflow.step(:combine, CombineAgent, deps: [:web_search, :wiki_search])
  """

  @type step :: %{
          name: atom(),
          agent: module(),
          deps: [atom()],
          opts: keyword()
        }

  @type t :: %__MODULE__{
          name: String.t(),
          steps: %{atom() => step()},
          order: [atom()]
        }

  defstruct name: "", steps: %{}, order: []

  @doc """
  Creates a new empty workflow graph.
  """
  @spec new(String.t()) :: t()
  def new(name \\ "workflow") do
    %__MODULE__{name: name}
  end

  @doc """
  Adds a step to the workflow graph.

  ## Options

    * `:deps` - List of step names this step depends on (default: [])
    * `:timeout` - Step-specific timeout override
    * `:max_retries` - Step-specific retry override

  ## Examples

      graph
      |> step(:research, ResearchAgent)
      |> step(:summarize, SummaryAgent, deps: [:research])
  """
  @spec step(t(), atom(), module(), keyword()) :: t()
  def step(%__MODULE__{} = graph, name, agent_module, opts \\ []) do
    {deps, step_opts} = Keyword.pop(opts, :deps, [])

    step = %{
      name: name,
      agent: agent_module,
      deps: deps,
      opts: step_opts
    }

    graph
    |> Map.update!(:steps, &Map.put(&1, name, step))
    |> recompute_order()
  end

  @doc """
  Returns groups of steps that can execute in parallel.

  Each group contains steps whose dependencies are fully satisfied
  by all previous groups.

  ## Examples

      iex> graph |> parallel_groups()
      [[:web_search, :wiki_search], [:combine]]
  """
  @spec parallel_groups(t()) :: [[atom()]]
  def parallel_groups(%__MODULE__{steps: steps}) do
    build_parallel_groups(steps, MapSet.new(), [])
  end

  @doc """
  Validates the workflow graph.

  Checks for:
  - Missing dependencies (step references non-existent step)
  - Cycles in the DAG
  - Empty workflow
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{steps: steps}) when map_size(steps) == 0 do
    {:error, :empty_workflow}
  end

  def validate(%__MODULE__{steps: steps} = graph) do
    with :ok <- validate_deps(steps),
         :ok <- validate_no_cycles(graph) do
      :ok
    end
  end

  # --- Private ---

  defp recompute_order(%__MODULE__{steps: steps} = graph) do
    case topological_sort(steps) do
      {:ok, order} -> %{graph | order: order}
      {:error, :cycle} -> raise "Cycle detected in workflow graph!"
    end
  end

  @doc false
  def topological_sort(steps) do
    graph_map =
      Map.new(steps, fn {name, step} -> {name, step.deps} end)

    do_topo_sort(graph_map, [], MapSet.new(), MapSet.new())
  end

  defp do_topo_sort(graph, sorted, visited, in_progress) do
    unvisited =
      graph
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(visited, &1))

    case unvisited do
      [] ->
        {:ok, Enum.reverse(sorted)}

      [node | _] ->
        case visit(node, graph, sorted, visited, in_progress) do
          {:ok, sorted, visited, in_progress} ->
            do_topo_sort(graph, sorted, visited, in_progress)

          {:error, :cycle} ->
            {:error, :cycle}
        end
    end
  end

  defp visit(node, graph, sorted, visited, in_progress) do
    cond do
      MapSet.member?(in_progress, node) ->
        {:error, :cycle}

      MapSet.member?(visited, node) ->
        {:ok, sorted, visited, in_progress}

      true ->
        in_progress = MapSet.put(in_progress, node)
        deps = Map.get(graph, node, [])

        result =
          Enum.reduce_while(deps, {:ok, sorted, visited, in_progress}, fn dep, {:ok, s, v, ip} ->
            case visit(dep, graph, s, v, ip) do
              {:ok, s, v, ip} -> {:cont, {:ok, s, v, ip}}
              {:error, :cycle} -> {:halt, {:error, :cycle}}
            end
          end)

        case result do
          {:ok, sorted, visited, in_progress} ->
            visited = MapSet.put(visited, node)
            in_progress = MapSet.delete(in_progress, node)
            sorted = [node | sorted]
            {:ok, sorted, visited, in_progress}

          {:error, :cycle} ->
            {:error, :cycle}
        end
    end
  end

  defp build_parallel_groups(steps, completed, groups) do
    # Find all steps whose deps are satisfied
    ready =
      steps
      |> Enum.filter(fn {name, step} ->
        not MapSet.member?(completed, name) and
          Enum.all?(step.deps, &MapSet.member?(completed, &1))
      end)
      |> Enum.map(fn {name, _} -> name end)
      |> Enum.sort()

    case ready do
      [] -> Enum.reverse(groups)
      group -> build_parallel_groups(steps, MapSet.union(completed, MapSet.new(group)), [group | groups])
    end
  end

  defp validate_deps(steps) do
    step_names = Map.keys(steps) |> MapSet.new()

    missing =
      Enum.flat_map(steps, fn {name, step} ->
        Enum.filter(step.deps, fn dep -> not MapSet.member?(step_names, dep) end)
        |> Enum.map(fn dep -> {name, dep} end)
      end)

    case missing do
      [] -> :ok
      pairs -> {:error, {:missing_deps, pairs}}
    end
  end

  defp validate_no_cycles(%__MODULE__{steps: steps}) do
    case topological_sort(steps) do
      {:ok, _} -> :ok
      {:error, :cycle} -> {:error, :cycle_detected}
    end
  end
end

defmodule Loom.Workflow do
  @moduledoc """
  Convenience module for building workflows.

  Delegates to `Loom.Workflow.Graph` for construction.
  """

  defdelegate new(name \\ "workflow"), to: Loom.Workflow.Graph
  defdelegate step(graph, name, agent, opts \\ []), to: Loom.Workflow.Graph
  defdelegate validate(graph), to: Loom.Workflow.Graph
  defdelegate parallel_groups(graph), to: Loom.Workflow.Graph
end
