# Loom — Coding Agent Swarm Example
#
# This example demonstrates a multi-agent coding swarm with parallel execution:
#
#         Planner
#        /       \
#     Coder    Tester      ← parallel
#        \       /
#        Reviewer
#
# Run with:
#
#     mix run examples/coding_agent.exs
#
# Make sure to set your LLM API key:
#
#     export LOOM_LLM_API_KEY=sk-...

# --- Define Agent Swarm ---

defmodule Examples.PlannerAgent do
  @moduledoc "Plans the implementation approach"
  use Loom.Agent

  @impl true
  def run(input, _opts) do
    prompt = """
    You are a senior software architect. Create a brief implementation plan for:

    #{input}

    Include:
    - Architecture decisions
    - Key modules/files
    - Interface design
    - Edge cases to consider

    Keep the plan concise and actionable.
    """

    Loom.LLM.chat(prompt, system: "You are a pragmatic software architect.")
  end
end

defmodule Examples.CoderAgent do
  @moduledoc "Writes the implementation"
  use Loom.Agent

  @impl true
  def run(%{deps: %{plan: plan}}, _opts) do
    prompt = """
    Based on this implementation plan, write clean, well-documented code.

    Plan:
    #{plan}

    Write idiomatic code with clear function names and type specs.
    """

    Loom.LLM.chat(prompt, system: "You are an expert programmer who writes clean code.")
  end
end

defmodule Examples.TesterAgent do
  @moduledoc "Writes tests for the implementation"
  use Loom.Agent

  @impl true
  def run(%{deps: %{plan: plan}}, _opts) do
    prompt = """
    Based on this implementation plan, write comprehensive tests.

    Plan:
    #{plan}

    Include:
    - Unit tests for each function
    - Edge cases
    - Error scenarios
    """

    Loom.LLM.chat(prompt, system: "You are a thorough QA engineer.")
  end
end

defmodule Examples.ReviewerAgent do
  @moduledoc "Reviews code and tests"
  use Loom.Agent

  @impl true
  def run(%{deps: %{code: code, test: test}}, _opts) do
    prompt = """
    Review the following code and tests. Provide:

    1. Code quality assessment
    2. Potential bugs
    3. Missing test coverage
    4. Performance concerns
    5. Final verdict: APPROVE or REQUEST_CHANGES

    Code:
    #{code}

    Tests:
    #{test}
    """

    Loom.LLM.chat(prompt, system: "You are a meticulous code reviewer.")
  end
end

# --- Build Workflow ---
#
# The DAG structure:
#
#     plan (Planner)
#       ├── code (Coder)     ← depends on plan
#       └── test (Tester)    ← depends on plan
#            ↓ both ↓
#          review (Reviewer) ← depends on code AND test
#

workflow =
  Loom.Workflow.new("coding_swarm")
  |> Loom.Workflow.step(:plan, Examples.PlannerAgent)
  |> Loom.Workflow.step(:code, Examples.CoderAgent, deps: [:plan])
  |> Loom.Workflow.step(:test, Examples.TesterAgent, deps: [:plan])
  |> Loom.Workflow.step(:review, Examples.ReviewerAgent, deps: [:code, :test])

IO.puts("""
╔══════════════════════════════════════╗
║     Loom — Coding Agent Swarm        ║
╠══════════════════════════════════════╣
║                                      ║
║          Planner                     ║
║         /       \\                    ║
║      Coder    Tester   ← parallel    ║
║         \\       /                    ║
║         Reviewer                     ║
║                                      ║
╚══════════════════════════════════════╝
""")

task = System.get_env("TASK", "Implement a GenServer-based rate limiter in Elixir")
IO.puts("🚀 Task: #{task}\n")
IO.puts("📊 Workflow groups: #{inspect(Loom.Workflow.parallel_groups(workflow))}\n")

case Loom.run(workflow, task, timeout: 120_000) do
  {:ok, results} ->
    IO.puts("✅ Swarm complete!\n")

    for {step, output} <- results do
      IO.puts("━━━ #{step |> Atom.to_string() |> String.upcase()} ━━━")
      IO.puts(output)
      IO.puts("")
    end

  {:error, state} ->
    IO.puts("❌ Swarm failed!")
    IO.inspect(state.errors, label: "Errors")
end
