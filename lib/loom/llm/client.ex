defmodule Loom.LLM do
  @moduledoc """
  LLM client abstraction for AI agent communication.

  Supports multiple providers (OpenAI, Anthropic, Ollama) with a
  unified interface. Configuration is loaded from application env.

  ## Configuration

      config :loom,
        llm_provider: :openai,
        llm_model: "gpt-4o",
        llm_api_key: "sk-...",
        llm_api_url: "https://api.openai.com/v1"

  ## Usage

      {:ok, response} = Loom.LLM.chat("What is the BEAM?")

      {:ok, response} = Loom.LLM.chat("Translate this",
        model: "gpt-4o-mini",
        system: "You are a translator."
      )
  """

  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Sends a chat message to the configured LLM provider.

  ## Options

    * `:model` - Override the default model
    * `:system` - System prompt
    * `:temperature` - Sampling temperature (0.0 - 2.0)
    * `:max_tokens` - Maximum tokens in response
    * `:provider` - Override the configured provider
  """
  @spec chat(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(prompt, opts \\ []) do
    provider = opts[:provider] || config(:llm_provider, :openai)

    messages = build_messages(prompt, opts)

    case provider do
      :openai -> call_openai(messages, opts)
      :anthropic -> call_anthropic(messages, opts)
      :ollama -> call_ollama(messages, opts)
      :mock -> {:ok, "Mock response for: #{prompt}"}
      other -> {:error, {:unsupported_provider, other}}
    end
  end

  @doc """
  Sends a list of messages to the LLM for multi-turn conversations.
  """
  @spec chat_messages([message()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat_messages(messages, opts \\ []) do
    provider = opts[:provider] || config(:llm_provider, :openai)

    case provider do
      :openai -> call_openai(messages, opts)
      :anthropic -> call_anthropic(messages, opts)
      :ollama -> call_ollama(messages, opts)
      :mock -> {:ok, "Mock response"}
      other -> {:error, {:unsupported_provider, other}}
    end
  end

  # --- Providers ---

  defp call_openai(messages, opts) do
    url = config(:llm_api_url, "https://api.openai.com/v1") <> "/chat/completions"
    api_key = config(:llm_api_key)
    model = opts[:model] || config(:llm_model, "gpt-4o")

    body = %{
      model: model,
      messages: messages,
      temperature: opts[:temperature] || 0.7,
      max_tokens: opts[:max_tokens] || 4096
    }

    case Req.post(url,
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp call_anthropic(messages, opts) do
    url = config(:llm_api_url, "https://api.anthropic.com/v1") <> "/messages"
    api_key = config(:llm_api_key)
    model = opts[:model] || config(:llm_model, "claude-sonnet-4-20250514")

    {system_msg, user_messages} = extract_system(messages)

    body = %{
      model: model,
      messages: user_messages,
      max_tokens: opts[:max_tokens] || 4096
    }

    body = if system_msg, do: Map.put(body, :system, system_msg), else: body

    case Req.post(url,
           json: body,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", "2023-06-01"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp call_ollama(messages, opts) do
    url = config(:llm_api_url, "http://localhost:11434") <> "/api/chat"
    model = opts[:model] || config(:llm_model, "llama3")

    body = %{
      model: model,
      messages: messages,
      stream: false
    }

    case Req.post(url, json: body) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  # --- Helpers ---

  defp build_messages(prompt, opts) do
    messages = [%{role: "user", content: prompt}]

    case opts[:system] do
      nil -> messages
      system -> [%{role: "system", content: system} | messages]
    end
  end

  defp extract_system(messages) do
    case Enum.split_with(messages, fn m -> m.role == "system" || m[:role] == "system" end) do
      {[%{content: sys} | _], rest} -> {sys, rest}
      {[], rest} -> {nil, rest}
    end
  end

  defp config(key, default \\ nil) do
    Application.get_env(:loom, key, default)
  end
end
