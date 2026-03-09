# Loom

[![CI](https://github.com/MeghanBao/Loom/actions/workflows/ci.yml/badge.svg)](https://github.com/MeghanBao/Loom/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Elixir](https://img.shields.io/badge/Elixir-1.15%2B-purple.svg)](https://elixir-lang.org/)

**A distributed runtime for orchestrating AI agents and workflows on the BEAM.**

<p align="center">
  <em>Weave intelligent workflows on the BEAM.</em>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#features">Features</a> •
  <a href="#examples">Examples</a> •
  <a href="#roadmap">Roadmap</a>
</p>

---

Inspired by [LangGraph](https://github.com/langchain-ai/langgraph) and [Temporal](https://temporal.io/), Loom uses the Erlang/Elixir actor model to run AI workflows as **resilient, distributed processes**.

Loom doesn't replace your LLM library — it provides the **runtime and orchestration layer** for running agent workflows reliably at scale.

## Features

- 🧵 **Actor-based AI agents** — Each agent is a BEAM process with supervision  
- 🔀 **DAG workflow orchestration** — Define complex pipelines as directed acyclic graphs  
- ⚡ **Parallel execution** — Independent steps run concurrently, automatically  
- 🛡️ **Fault-tolerant execution** — OTP supervisors, retries, and graceful error handling  
- 🌐 **Distributed runtime** — Schedule tasks across multiple BEAM nodes  
- 📡 **Telemetry built-in** — Observable by default with `:telemetry` events  
- 🔌 **Pluggable LLM providers** — OpenAI, Anthropic, Ollama out of the box  

## Installation

Add `loom` to your `mix.exs`:

```elixir
def deps do
  [
    {:loom, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Define Agents

```elixir
defmodule ResearchAgent do
  use Loom.Agent

  @impl true
  def run(input, _opts) do
    Loom.LLM.chat("Research: #{input}")
  end
end

defmodule SummaryAgent do
  use Loom.Agent

  @impl true
  def run(%{deps: %{research: data}}, _opts) do
    Loom.LLM.chat("Summarize: #{data}")
  end
end
```

### 2. Build a Workflow

```elixir
workflow =
  Loom.Workflow.new("research_pipeline")
  |> Loom.Workflow.step(:research, ResearchAgent)
  |> Loom.Workflow.step(:summarize, SummaryAgent, deps: [:research])
```

### 3. Execute

```elixir
{:ok, results} = Loom.run(workflow, "What is the BEAM?")

results[:research]   # => "The BEAM is..."
results[:summarize]  # => "In summary..."
```

## Architecture

```
                    User
                     │
                     ▼
              ┌─────────────┐
              │   Workflow   │  DAG definition
              └──────┬──────┘
                     │
           ┌─────────┴─────────┐
           ▼                   ▼
    ┌─────────────┐    ┌─────────────┐
    │  Scheduler  │    │ State Store │
    └──────┬──────┘    └─────────────┘
           │
           ▼
    ┌─────────────┐
    │  Executor   │  Parallel group execution
    └──────┬──────┘
           │
     ┌─────┼─────┐
     ▼     ▼     ▼
   ┌───┐ ┌───┐ ┌───┐
   │ A │ │ A │ │ A │  Agent Pool (BEAM processes)
   └─┬─┘ └─┬─┘ └─┬─┘
     │     │     │
     ▼     ▼     ▼
   LLM  Tools  APIs
```

### Core Concepts

| Concept | BEAM Mapping | Description |
|---------|-------------|-------------|
| **Agent** | Process | Autonomous unit of work with supervision |
| **Workflow** | DAG | Directed acyclic graph of agent steps |
| **Scheduler** | GenServer | Queue-based workflow dispatcher |
| **Executor** | Task.async_stream | Parallel step execution engine |
| **Runtime** | Node/Distribution | Multi-node task distribution |

## Parallel Execution

Independent steps execute concurrently — no configuration needed:

```elixir
workflow =
  Loom.Workflow.new("parallel_search")
  |> Loom.Workflow.step(:web_search, WebSearchAgent)
  |> Loom.Workflow.step(:wiki_search, WikiSearchAgent)
  |> Loom.Workflow.step(:combine, CombineAgent, deps: [:web_search, :wiki_search])
```

Execution groups are computed automatically:

```
Group 1: [:web_search, :wiki_search]  ← parallel
Group 2: [:combine]                   ← after both complete
```

## Fault Tolerance

Agents run under OTP supervision with configurable retry policies:

```elixir
defmodule ResilientAgent do
  use Loom.Agent, timeout: 10_000, max_retries: 5

  @impl true
  def run(input, _opts) do
    # If this fails, it retries up to 5 times
    Loom.LLM.chat("Process: #{input}")
  end

  @impl true
  def on_error(:timeout, _input), do: :retry
  def on_error(:rate_limited, _input), do: :retry
  def on_error(_other, _input), do: :abort
end
```

## Agent Swarm

Build multi-agent systems where each agent is a BEAM process:

```elixir
workflow =
  Loom.Workflow.new("coding_swarm")
  |> Loom.Workflow.step(:plan, PlannerAgent)
  |> Loom.Workflow.step(:code, CoderAgent, deps: [:plan])
  |> Loom.Workflow.step(:test, TesterAgent, deps: [:plan])
  |> Loom.Workflow.step(:review, ReviewerAgent, deps: [:code, :test])
```

```
      Planner
     /       \
  Coder    Tester    ← parallel
     \       /
     Reviewer
```

## Distributed Execution

Run workflows across multiple BEAM nodes:

```elixir
# Nodes connect automatically
Node.connect(:"worker@host2")
Node.connect(:"worker@host3")

# Tasks are distributed across available nodes
Loom.run(workflow, input)
```

## Telemetry

Loom emits telemetry events for full observability:

```elixir
:telemetry.attach("my-handler", [:loom, :agent, :stop], fn _event, measurements, metadata, _config ->
  IO.puts("Agent #{metadata.agent} completed in #{measurements.duration}ms")
end, nil)
```

Events:
- `[:loom, :agent, :start | :stop | :error]`
- `[:loom, :workflow, :start | :stop | :error]`
- `[:loom, :step, :start | :stop | :error]`

## Configuration

```elixir
# config/config.exs
config :loom,
  llm_provider: :openai,          # :openai | :anthropic | :ollama
  llm_model: "gpt-4o",
  llm_api_key: "sk-...",
  max_concurrent_workflows: 10,
  agent_timeout: 30_000,
  agent_max_retries: 3
```

## Examples

See the [`examples/`](examples/) directory:

- **[research_agent.exs](examples/research_agent.exs)** — Research → Analyze → Summarize pipeline
- **[coding_agent.exs](examples/coding_agent.exs)** — Planner → Coder/Tester → Reviewer swarm

Run an example:

```bash
export LOOM_LLM_API_KEY=sk-...
mix run examples/research_agent.exs
```

## Roadmap

### v0.1 — Foundation ✅
- Agent runtime with supervision
- DAG workflow orchestration
- Scheduler with concurrency control
- Pluggable LLM client
- Telemetry integration

### v0.2 — Reliability
- Workflow state persistence
- Distributed execution improvements
- Streaming pipelines
- Advanced retry strategies

### v0.3 — Observability
- LiveView dashboard
- Workflow visualization
- Execution replay

### v0.4 — Ecosystem
- Tool/function calling framework
- Agent communication channels
- Plugin system

## Why Loom?

| | Python (LangGraph) | TypeScript (CrewAI) | **Elixir (Loom)** |
|---|---|---|---|
| Concurrency | Threading/asyncio | Event loop | **BEAM processes** |
| Fault tolerance | Manual | Manual | **OTP supervisors** |
| Distribution | Complex | Complex | **Built-in** |
| Scalability | Limited | Limited | **Millions of processes** |

The BEAM was literally designed for the exact problems AI agent systems face: massive concurrency, fault tolerance, and distribution.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
git clone https://github.com/MeghanBao/loom
cd loom
mix deps.get
mix test
```

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Loom</strong> — Weave intelligent workflows on the BEAM.
</p>
