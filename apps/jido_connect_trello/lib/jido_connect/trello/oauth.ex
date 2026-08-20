defmodule Jido.Connect.Trello.OAuth do
  @moduledoc """
  Builds a hosted Trello MCP OAuth credential for a host callback flow.

  The host stores `secret_data` only in encrypted, single-use OAuth state. The
  completed credential keeps refresh data out of the runtime lease. Only the
  fixed `mcp_endpoint` map belongs in the short-lived connector lease.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Trello.Contract

  @scopes ~w(trello:read trello:write trello:search)

  @spec begin(keyword()) :: {:ok, map()} | {:error, Error.error()}
  def begin(opts) when is_list(opts) do
    with {:ok, result} <- flow().begin(Contract.endpoint(), opts),
         authorize_url when is_binary(authorize_url) <- value(result, :authorize_url),
         state when is_binary(state) and byte_size(state) in 32..512 <- value(result, :state),
         transaction when is_map(transaction) <- value(result, :transaction),
         :ok <- authorize_url(authorize_url) do
      {:ok,
       %{authorize_url: authorize_url, state: state, secret_data: stringify_keys(transaction)}}
    else
      _error -> oauth_error(:trello_oauth_begin_failed)
    end
  rescue
    _exception -> oauth_error(:trello_oauth_begin_failed)
  end

  def begin(_opts), do: oauth_error(:trello_oauth_begin_failed)

  @spec exchange_code(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.error()}
  def exchange_code(code, secret_data, opts)
      when is_binary(code) and code != "" and is_map(secret_data) and is_list(opts) do
    with {:ok, tokens} <- flow().exchange_code(code, secret_data, opts),
         {:ok, credential} <- credential(tokens, nil) do
      {:ok, credential}
    else
      _error -> oauth_error(:trello_oauth_exchange_failed)
    end
  rescue
    _exception -> oauth_error(:trello_oauth_exchange_failed)
  end

  def exchange_code(_code, _secret_data, _opts),
    do: oauth_error(:trello_oauth_exchange_failed)

  @spec refresh_token(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.error()}
  def refresh_token(refresh_token, credential, opts)
      when is_binary(refresh_token) and refresh_token != "" and is_map(credential) and
             is_list(opts) do
    with oauth_client when is_map(oauth_client) <- value(credential, :oauth_client),
         {:ok, tokens} <- flow().refresh_token(refresh_token, oauth_client, opts),
         {:ok, refreshed} <- credential(tokens, refresh_token) do
      {:ok, refreshed}
    else
      _error -> oauth_error(:trello_oauth_refresh_failed)
    end
  rescue
    _exception -> oauth_error(:trello_oauth_refresh_failed)
  end

  def refresh_token(_refresh_token, _credential, _opts),
    do: oauth_error(:trello_oauth_refresh_failed)

  defp credential(tokens, fallback_refresh) when is_map(tokens) do
    access_token = value(tokens, :access_token)
    refresh_token = value(tokens, :refresh_token) || fallback_refresh
    oauth_client = value(tokens, :oauth_client)

    with true <- present?(access_token),
         true <- present?(refresh_token),
         {:ok, oauth_client} <- oauth_client(oauth_client) do
      {:ok,
       %{
         mcp_endpoint: endpoint(access_token),
         refresh_token: refresh_token,
         oauth_client: oauth_client,
         scope: value(tokens, :scope) || @scopes,
         expires_in: value(tokens, :expires_in)
       }}
    else
      _error -> oauth_error(:trello_oauth_token_invalid)
    end
  end

  defp credential(_tokens, _fallback_refresh), do: oauth_error(:trello_oauth_token_invalid)

  defp oauth_client(client) when is_map(client) do
    client_id = value(client, :client_id)
    token_endpoint = value(client, :token_endpoint)
    client_secret = value(client, :client_secret)

    uri = if is_binary(token_endpoint), do: URI.parse(token_endpoint), else: %URI{}

    if present?(client_id) and uri.scheme == "https" and is_binary(uri.host) and
         is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) and
         (is_nil(client_secret) or present?(client_secret)) do
      {:ok,
       %{
         "client_id" => client_id,
         "client_secret" => client_secret,
         "token_endpoint" => token_endpoint
       }}
    else
      oauth_error(:trello_oauth_client_invalid)
    end
  end

  defp oauth_client(_client), do: oauth_error(:trello_oauth_client_invalid)

  defp endpoint(access_token) do
    %{
      backend: :ex_mcp,
      transport:
        {:streamable_http,
         [
           base_url: "https://mcp.trello.com",
           mcp_path: "/v1",
           headers: [{"authorization", "Bearer #{access_token}"}]
         ]},
      client_info: %{name: "jido-connect-trello", version: "0.8.0"},
      client_options: [],
      capabilities: %{},
      timeouts: %{request_ms: 30_000}
    }
  end

  defp authorize_url(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, userinfo: nil} when is_binary(host) and host != "" ->
        :ok

      _uri ->
        oauth_error(:trello_oauth_authorize_url_invalid)
    end
  end

  defp flow do
    Application.get_env(
      :jido_connect_trello,
      :trello_oauth_flow,
      Jido.Connect.Trello.OAuth.DefaultFlow
    )
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp present?(value), do: is_binary(value) and value != "" and String.trim(value) == value

  defp oauth_error(reason) do
    {:error,
     Error.auth("Trello hosted MCP OAuth failed",
       reason: reason,
       details: %{provider: :trello}
     )}
  end
end
