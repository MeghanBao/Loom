defmodule Loom.Workflow.Executor do
  @moduledoc """
  Executes a workflow graph, respecting dependencies and parallelism.

  The executor processes the DAG in topological order, running independent
  steps concurrently using Task.async_stream. Each step's output becomes
  available as input to dependent steps.
  """

  alias Loom.Workflow.{Graph, State}

  @doc """
  Executes a workflow with the given input.

  Steps are executed in parallel groups — each group contains steps whose
  dependencies are fully satisfied. Within a group, all steps run concurrently.

  Returns `{:ok, results_map}` or `{:error, state}` if any step fails.
  """
  @spec execute(Graph.t(), term(), keyword()) :: {:ok, map()} | {:error, State.t()}
  def execute(%Graph{} = graph, input, opts \\ []) do
    with :ok <- Graph.validate(graph) do
      state = State.new(graph, input)
      groups = Graph.parallel_groups(graph)

      :telemetry.execute(
        [:loom, :workflow, :start],
        %{system_time: System.system_time()},
        %{workflow: graph.name, steps: Map.keys(graph.steps)}
      )

      start_time = System.monotonic_time()
      result = execute_groups(groups, graph, state, input, opts)
      duration = System.monotonic_time() - start_time

      case result do
        {:ok, final_state} ->
          :telemetry.execute(
            [:loom, :workflow, :stop],
            %{duration: duration},
            %{workflow: graph.name, results: final_state.results}
          )

          {:ok, final_state.results}

        {:error, final_state} ->
          :telemetry.execute(
            [:loom, :workflow, :error],
            %{duration: duration},
            %{workflow: graph.name, errors: final_state.errors}
          )

          {:error, final_state}
      end
    end
  end

  defp execute_groups([], _graph, state, _input, _opts) do
    final_state = State.complete(state)

    if State.has_errors?(final_state) do
      {:error, final_state}
    else
      {:ok, final_state}
    end
  end

  defp execute_groups([group | rest], graph, state, input, opts) do
    # Mark all steps in this group as running
    state = Enum.reduce(group, state, &State.mark_running(&2, &1))

    # Execute all steps in the group concurrently
    results =
      group
      |> Task.async_stream(
        fn step_name ->
          step = Map.fetch!(graph.steps, step_name)
          step_input = build_step_input(step, input, state)

          :telemetry.execute(
            [:loom, :step, :start],
            %{system_time: System.system_time()},
            %{workflow: graph.name, step: step_name}
          )

          step_start = System.monotonic_time()
          result = Loom.Agent.execute(step.agent, step_input, step.opts)
          step_duration = System.monotonic_time() - step_start

          case result do
            {:ok, _} ->
              :telemetry.execute(
                [:loom, :step, :stop],
                %{duration: step_duration},
                %{workflow: graph.name, step: step_name}
              )

            {:error, reason} ->
              :telemetry.execute(
                [:loom, :step, :error],
                %{duration: step_duration},
                %{workflow: graph.name, step: step_name, error: reason}
              )
          end

          {step_name, result}
        end,
        ordered: false,
        timeout: opts[:timeout] || 60_000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, {:task_exit, reason}}
      end)

    # Update state with results
    {state, has_failure} =
      Enum.reduce(results, {state, false}, fn
        {step_name, {:ok, result}}, {state, failed} ->
          {State.put_result(state, step_name, result), failed}

        {step_name, {:error, reason}}, {state, _failed} ->
          {State.put_error(state, step_name, reason), true}
      end)

    if has_failure do
      {:error, State.complete(state)}
    else
      execute_groups(rest, graph, state, input, opts)
    end
  end

  defp build_step_input(step, original_input, state) do
    case step.deps do
      [] ->
        original_input

      deps ->
        dep_results = Map.take(state.results, deps)
        %{input: original_input, deps: dep_results}
    end
  end
end
