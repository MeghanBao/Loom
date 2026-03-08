defmodule Loom.Scheduler.QueueTest do
  use ExUnit.Case, async: true

  alias Loom.Scheduler.Queue

  describe "new/0" do
    test "creates an empty queue" do
      q = Queue.new()
      assert Queue.size(q) == 0
      assert Queue.empty?(q)
    end
  end

  describe "enqueue/dequeue" do
    test "FIFO ordering" do
      q =
        Queue.new()
        |> Queue.enqueue(:first)
        |> Queue.enqueue(:second)
        |> Queue.enqueue(:third)

      assert Queue.size(q) == 3

      {{:value, :first}, q} = Queue.dequeue(q)
      {{:value, :second}, q} = Queue.dequeue(q)
      {{:value, :third}, q} = Queue.dequeue(q)

      assert Queue.empty?(q)
    end

    test "dequeue from empty queue" do
      q = Queue.new()
      assert {:empty, ^q} = Queue.dequeue(q)
    end
  end

  describe "size/1" do
    test "tracks size correctly" do
      q = Queue.new()
      assert Queue.size(q) == 0

      q = Queue.enqueue(q, :a)
      assert Queue.size(q) == 1

      q = Queue.enqueue(q, :b)
      assert Queue.size(q) == 2

      {{:value, _}, q} = Queue.dequeue(q)
      assert Queue.size(q) == 1
    end
  end
end
