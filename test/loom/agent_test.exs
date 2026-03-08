defmodule Loom.Agent.AgentTest do
  use ExUnit.Case, async: true

  defmodule SuccessAgent do
    use Loom.Agent
    @impl true
    def run(input, _opts), do: {:ok, "processed: #{input}"}
  end

  defmodule FailAgent do
    use Loom.Agent, max_retries: 0
    @impl true
    def run(_input, _opts), do: {:error, :intentional_failure}
  end

  defmodule RetryAgent do
    use Loom.Agent, max_retries: 2

    @impl true
    def run(input, _opts) do
      # Use the process dictionary to track retry count
      count = Process.get(:retry_count, 0)
      Process.put(:retry_count, count + 1)

      if count < 2 do
        {:error, :not_yet}
      else
        {:ok, "finally: #{input}"}
      end
    end
  end

  defmodule CustomErrorAgent do
    use Loom.Agent, max_retries: 3

    @impl true
    def run(_input, _opts), do: {:error, :some_error}

    @impl true
    def on_error(:some_error, _input), do: :abort
  end

  describe "execute/3" do
    test "executes a successful agent" do
      assert {:ok, "processed: hello"} = Loom.Agent.execute(SuccessAgent, "hello")
    end

    test "returns error for failing agent with no retries" do
      assert {:error, :intentional_failure} = Loom.Agent.execute(FailAgent, "test")
    end

    test "respects custom on_error behavior" do
      assert {:error, :some_error} = Loom.Agent.execute(CustomErrorAgent, "test")
    end
  end

  describe "behaviour" do
    test "defines the run callback" do
      assert function_exported?(SuccessAgent, :run, 2)
    end

    test "defines the on_error callback with default" do
      assert function_exported?(SuccessAgent, :on_error, 2)
      assert SuccessAgent.on_error(:test, :input) == :retry
    end

    test "stores agent options" do
      assert FailAgent.__loom_agent_opts__()[:max_retries] == 0
    end
  end
end
