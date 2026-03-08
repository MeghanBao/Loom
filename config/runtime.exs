import Config

if config_env() == :prod do
  config :loom,
    llm_api_key: System.get_env("LOOM_LLM_API_KEY"),
    llm_api_url: System.get_env("LOOM_LLM_API_URL", "https://api.openai.com/v1"),
    llm_provider: String.to_atom(System.get_env("LOOM_LLM_PROVIDER", "openai")),
    llm_model: System.get_env("LOOM_LLM_MODEL", "gpt-4o")
end
