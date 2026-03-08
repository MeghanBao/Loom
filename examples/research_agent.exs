# Loom — Research Agent Pipeline Example
#
# This example demonstrates a 3-step research pipeline:
#
#     Query → Research → Analyze → Summarize
#
# Run with:
#
#     mix run examples/research_agent.exs
#
# Make sure to set your LLM API key:
#
#     export LOOM_LLM_API_KEY=sk-...

# --- Define Agents ---

defmodule Examples.ResearchAgent do
  @moduledoc "Researches a topic using LLM"
  use Loom.Agent

  @impl true
  def run(input, _opts) do
    prompt = """
    You are a research assistant. Research the following topic thoroughly
    and provide key findings with sources.

    Topic: #{input}
    """

    Loom.LLM.chat(prompt, system: "You are a thorough research assistant.")
  end
end

defmodule Examples.AnalyzeAgent do
  @moduledoc "Analyzes research findings"
  use Loom.Agent

  @impl true
  def run(%{deps: %{research: research}}, _opts) do
    prompt = """
    Analyze the following research findings. Identify:
    1. Key themes
    2. Contradictions
    3. Knowledge gaps
    4. Actionable insights

    Research:
    #{research}
    """

    Loom.LLM.chat(prompt, system: "You are an analytical thinker.")
  end
end

defmodule Examples.SummaryAgent do
  @moduledoc "Produces a final summary"
  use Loom.Agent

  @impl true
  def run(%{deps: %{analyze: analysis}}, _opts) do
    prompt = """
    Write a concise executive summary based on this analysis.
    Keep it under 200 words and highlight the most important findings.

    Analysis:
    #{analysis}
    """

    Loom.LLM.chat(prompt, system: "You are a concise technical writer.")
  end
end

# --- Build Workflow ---

workflow =
  Loom.Workflow.new("research_pipeline")
  |> Loom.Workflow.step(:research, Examples.ResearchAgent)
  |> Loom.Workflow.step(:analyze, Examples.AnalyzeAgent, deps: [:research])
  |> Loom.Workflow.step(:summarize, Examples.SummaryAgent, deps: [:analyze])

IO.puts("""
╔══════════════════════════════════════╗
║   Loom — Research Agent Pipeline     ║
╠══════════════════════════════════════╣
║                                      ║
║   Query → Research → Analyze         ║
║                      → Summarize     ║
║                                      ║
╚══════════════════════════════════════╝
""")

topic = System.get_env("TOPIC", "How does the BEAM VM achieve fault tolerance?")
IO.puts("🔍 Researching: #{topic}\n")

case Loom.run(workflow, topic) do
  {:ok, results} ->
    IO.puts("✅ Pipeline complete!\n")
    IO.puts("━━━ Research ━━━")
    IO.puts(results[:research])
    IO.puts("\n━━━ Analysis ━━━")
    IO.puts(results[:analyze])
    IO.puts("\n━━━ Summary ━━━")
    IO.puts(results[:summarize])

  {:error, state} ->
    IO.puts("❌ Pipeline failed!")
    IO.inspect(state.errors, label: "Errors")
end
