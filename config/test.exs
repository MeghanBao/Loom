import Config

config :loom,
  llm_provider: :mock,
  agent_timeout: 5_000,
  agent_max_retries: 1

config :logger, level: :warning
