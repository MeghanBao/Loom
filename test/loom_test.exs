defmodule LoomTest do
  use ExUnit.Case, async: true

  defmodule EchoAgent do
    use Loom.Agent

    @impl true
    def run(input, _opts), do: {:ok, "echo: #{input}"}
  end

  defmodule UpperAgent do
    use Loom.Agent

    @impl true
    def run(%{deps: %{echo: result}}, _opts) do
      {:ok, String.upcase(result)}
    end

    def run(input, _opts) when is_binary(input) do
      {:ok, String.upcase(input)}
    end
  end

  test "runs a simple workflow end-to-end" do
    workflow =
      Loom.Workflow.new("test")
      |> Loom.Workflow.step(:echo, EchoAgent)
      |> Loom.Workflow.step(:upper, UpperAgent, deps: [:echo])

    assert {:ok, results} = Loom.run(workflow, "hello")
    assert results[:echo] == "echo: hello"
    assert results[:upper] == "ECHO: HELLO"
  end
end
