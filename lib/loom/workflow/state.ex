defmodule Loom.Workflow.State do
  @moduledoc """
  Tracks the execution state of a running workflow.

  Maintains results, errors, and status for each step.
  Serializable for potential persistence and recovery.
  """

  @type step_status :: :pending | :running | :completed | :failed | :skipped

  @type t :: %__MODULE__{
          workflow_name: String.t(),
          input: term(),
          results: %{atom() => term()},
          errors: %{atom() => term()},
          statuses: %{atom() => step_status()},
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }

  defstruct workflow_name: "",
            input: nil,
            results: %{},
            errors: %{},
            statuses: %{},
            started_at: nil,
            completed_at: nil

  @doc """
  Creates a new workflow state for the given workflow and input.
  """
  @spec new(Loom.Workflow.Graph.t(), term()) :: t()
  def new(%Loom.Workflow.Graph{name: name, steps: steps}, input) do
    statuses = Map.new(steps, fn {step_name, _} -> {step_name, :pending} end)

    %__MODULE__{
      workflow_name: name,
      input: input,
      statuses: statuses,
      started_at: DateTime.utc_now()
    }
  end

  @doc """
  Marks a step as running.
  """
  @spec mark_running(t(), atom()) :: t()
  def mark_running(state, step_name) do
    %{state | statuses: Map.put(state.statuses, step_name, :running)}
  end

  @doc """
  Records a successful step result.
  """
  @spec put_result(t(), atom(), term()) :: t()
  def put_result(state, step_name, result) do
    %{state |
      results: Map.put(state.results, step_name, result),
      statuses: Map.put(state.statuses, step_name, :completed)
    }
  end

  @doc """
  Records a step error.
  """
  @spec put_error(t(), atom(), term()) :: t()
  def put_error(state, step_name, error) do
    %{state |
      errors: Map.put(state.errors, step_name, error),
      statuses: Map.put(state.statuses, step_name, :failed)
    }
  end

  @doc """
  Marks the workflow as completed.
  """
  @spec complete(t()) :: t()
  def complete(state) do
    %{state | completed_at: DateTime.utc_now()}
  end

  @doc """
  Checks if all steps have completed (either successfully or with failure).
  """
  @spec finished?(t()) :: boolean()
  def finished?(state) do
    Enum.all?(state.statuses, fn {_, status} ->
      status in [:completed, :failed, :skipped]
    end)
  end

  @doc """
  Returns true if any step failed.
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(state) do
    map_size(state.errors) > 0
  end
end
