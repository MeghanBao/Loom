import Config

config :loom,
  # Default LLM provider (:openai | :anthropic | :ollama)
  llm_provider: :openai,

  # Default model
  llm_model: "gpt-4o",

  # Scheduler concurrency limit
  max_concurrent_workflows: 10,

  # Agent defaults
  agent_timeout: 30_000,
  agent_max_retries: 3

config :logger,
  level: :info

import_config "#{config_env()}.exs"
