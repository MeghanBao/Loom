defmodule Loom.Workflow.GraphTest do
  use ExUnit.Case, async: true

  alias Loom.Workflow.Graph

  defmodule StubAgent do
    use Loom.Agent
    @impl true
    def run(input, _opts), do: {:ok, input}
  end

  describe "new/1" do
    test "creates an empty workflow" do
      graph = Graph.new("test")
      assert graph.name == "test"
      assert graph.steps == %{}
      assert graph.order == []
    end
  end

  describe "step/4" do
    test "adds a step to the graph" do
      graph =
        Graph.new("test")
        |> Graph.step(:a, StubAgent)

      assert Map.has_key?(graph.steps, :a)
      assert graph.steps[:a].agent == StubAgent
      assert graph.steps[:a].deps == []
    end

    test "adds a step with dependencies" do
      graph =
        Graph.new("test")
        |> Graph.step(:a, StubAgent)
        |> Graph.step(:b, StubAgent, deps: [:a])

      assert graph.steps[:b].deps == [:a]
    end

    test "computes topological order" do
      graph =
        Graph.new("test")
        |> Graph.step(:c, StubAgent, deps: [:b])
        |> Graph.step(:a, StubAgent)
        |> Graph.step(:b, StubAgent, deps: [:a])

      assert graph.order == [:a, :b, :c]
    end
  end

  describe "parallel_groups/1" do
    test "groups independent steps together" do
      graph =
        Graph.new("test")
        |> Graph.step(:a, StubAgent)
        |> Graph.step(:b, StubAgent)
        |> Graph.step(:c, StubAgent, deps: [:a, :b])

      groups = Graph.parallel_groups(graph)
      assert length(groups) == 2

      [first_group, second_group] = groups
      assert :a in first_group
      assert :b in first_group
      assert second_group == [:c]
    end

    test "sequential steps are separate groups" do
      graph =
        Graph.new("test")
        |> Graph.step(:a, StubAgent)
        |> Graph.step(:b, StubAgent, deps: [:a])
        |> Graph.step(:c, StubAgent, deps: [:b])

      groups = Graph.parallel_groups(graph)
      assert groups == [[:a], [:b], [:c]]
    end

    test "diamond DAG" do
      # a → b, a → c, b → d, c → d
      graph =
        Graph.new("diamond")
        |> Graph.step(:a, StubAgent)
        |> Graph.step(:b, StubAgent, deps: [:a])
        |> Graph.step(:c, StubAgent, deps: [:a])
        |> Graph.step(:d, StubAgent, deps: [:b, :c])

      groups = Graph.parallel_groups(graph)
      assert length(groups) == 3

      [g1, g2, g3] = groups
      assert g1 == [:a]
      assert :b in g2
      assert :c in g2
      assert g3 == [:d]
    end
  end

  describe "validate/1" do
    test "returns error for empty workflow" do
      assert {:error, :empty_workflow} = Graph.validate(Graph.new("empty"))
    end

    test "returns ok for valid workflow" do
      graph =
        Graph.new("test")
        |> Graph.step(:a, StubAgent)
        |> Graph.step(:b, StubAgent, deps: [:a])

      assert :ok = Graph.validate(graph)
    end
  end

  describe "topological_sort/1" do
    test "handles complex DAG" do
      steps = %{
        a: %{deps: []},
        b: %{deps: [:a]},
        c: %{deps: [:a]},
        d: %{deps: [:b, :c]},
        e: %{deps: [:d]}
      }

      assert {:ok, order} = Graph.topological_sort(steps)
      assert hd(order) == :a
      assert List.last(order) == :e

      # b and c must come after a but before d
      a_idx = Enum.find_index(order, &(&1 == :a))
      b_idx = Enum.find_index(order, &(&1 == :b))
      c_idx = Enum.find_index(order, &(&1 == :c))
      d_idx = Enum.find_index(order, &(&1 == :d))

      assert a_idx < b_idx
      assert a_idx < c_idx
      assert b_idx < d_idx
      assert c_idx < d_idx
    end
  end
end
