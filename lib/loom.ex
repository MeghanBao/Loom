defmodule Loom do
  @moduledoc """
  Loom — A distributed runtime for orchestrating AI agents and workflows on the BEAM.

  Loom provides a simple yet powerful API for defining AI agent workflows as
  directed acyclic graphs (DAGs) and executing them with built-in fault tolerance,
  parallel execution, and distributed scheduling.

  ## Quick Start

      # Define agents
      defmodule ResearchAgent do
        use Loom.Agent

        @impl true
        def run(input, _opts) do
          Loom.LLM.chat("Research the following topic: \#{input}")
        end
      end

      # Build a workflow
      workflow =
        Loom.Workflow.new("research_pipeline")
        |> Loom.Workflow.step(:research, ResearchAgent)
        |> Loom.Workflow.step(:summarize, SummaryAgent, deps: [:research])

      # Execute
      {:ok, result} = Loom.run(workflow, "What is the BEAM?")
  """

  alias Loom.Scheduler

  @doc """
  Runs a workflow synchronously with the given input.

  Returns `{:ok, results}` where results is a map of `%{step_name => output}`,
  or `{:error, reason}` if the workflow fails.

  ## Options

    * `:timeout` - Maximum time for the entire workflow (default: 60_000ms)

  ## Examples

      {:ok, results} = Loom.run(workflow, "Hello")
      results[:research]  # => "Research output..."
  """
  @spec run(Loom.Workflow.Graph.t(), term(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(%Loom.Workflow.Graph{} = workflow, input, opts \\ []) do
    Scheduler.execute_sync(workflow, input, opts)
  end

  @doc """
  Runs a workflow asynchronously, returning a task reference.

  ## Examples

      {:ok, ref} = Loom.run_async(workflow, "Hello")
      # ... do other work ...
      {:ok, results} = Loom.await(ref)
  """
  @spec run_async(Loom.Workflow.Graph.t(), term(), keyword()) :: {:ok, reference()}
  def run_async(%Loom.Workflow.Graph{} = workflow, input, opts \\ []) do
    Scheduler.execute_async(workflow, input, opts)
  end

  @doc """
  Awaits the result of an async workflow execution.
  """
  @spec await(reference(), timeout()) :: {:ok, map()} | {:error, term()}
  def await(ref, timeout \\ 60_000) do
    Scheduler.await(ref, timeout)
  end
end
