defmodule Loom.Scheduler.Queue do
  @moduledoc """
  Priority queue for workflow execution requests.

  FIFO by default with optional priority levels.
  Uses Erlang's `:queue` module for efficient double-ended queue operations.
  """

  @type t :: %__MODULE__{
          queue: :queue.queue(),
          size: non_neg_integer()
        }

  defstruct queue: :queue.new(), size: 0

  @doc """
  Creates a new empty queue.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Adds an item to the back of the queue.
  """
  @spec enqueue(t(), term()) :: t()
  def enqueue(%__MODULE__{queue: q, size: size}, item) do
    %__MODULE__{queue: :queue.in(item, q), size: size + 1}
  end

  @doc """
  Removes and returns the front item from the queue.

  Returns `{{:value, item}, updated_queue}` or `{:empty, queue}`.
  """
  @spec dequeue(t()) :: {{:value, term()}, t()} | {:empty, t()}
  def dequeue(%__MODULE__{queue: q, size: size} = queue) do
    case :queue.out(q) do
      {{:value, item}, rest} ->
        {{:value, item}, %__MODULE__{queue: rest, size: size - 1}}

      {:empty, _} ->
        {:empty, queue}
    end
  end

  @doc """
  Returns the number of items in the queue.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Returns true if the queue is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{size: 0}), do: true
  def empty?(_), do: false
end
