defmodule Jido.Connect.Trello.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Trello.OAuth
  alias Jido.Connect.Trello.OAuth.DefaultFlow

  @state "trello-state-0123456789abcdefghijkl"

  defmodule FakeFlow do
    @state "trello-state-0123456789abcdefghijkl"

    def begin("https://mcp.trello.com/v1", opts) do
      send(self(), {:oauth_begin, opts})

      {:ok,
       %{
         authorize_url: "https://auth.example/authorize?state=#{@state}",
         state: @state,
         transaction: %{"redirect_uri" => Keyword.fetch!(opts, :redirect_uri)}
       }}
    end

    def exchange_code("one-use-code", transaction, opts) do
      send(self(), {:oauth_exchange, transaction, opts})

      {:ok,
       %{
         access_token: "trello-access-token",
         refresh_token: "trello-refresh-token",
         oauth_client: %{
           "client_id" => "trello-client",
           "token_endpoint" => "https://auth.example/token"
         },
         scope: "trello:read trello:write trello:search",
         expires_in: 3_600
       }}
    end

    def refresh_token("trello-refresh-token", oauth_client, opts) do
      send(self(), {:oauth_refresh, oauth_client, opts})

      {:ok,
       %{
         access_token: "trello-refreshed-token",
         oauth_client: oauth_client,
         scope: "trello:read trello:write trello:search",
         expires_in: 3_600
       }}
    end
  end

  defmodule FakeBackend do
    def discover_resource("https://mcp.trello.com/v1", []),
      do: {:ok, %{authorization_servers: [%{issuer: "https://auth.example"}]}}

    def discover_authorization("https://auth.example", []) do
      {:ok,
       %{
         "authorization_endpoint" => "https://auth.example/authorize",
         "token_endpoint" => "https://auth.example/token",
         "registration_endpoint" => "https://auth.example/register",
         "authorization_response_iss_parameter_supported" => true
       }}
    end

    def register_client(request) do
      send(self(), {:registered, request})
      {:ok, %{client_id: "dynamic-client", client_secret: nil}}
    end

    def start_authorization(params) do
      send(self(), {:authorization_started, params})

      {:ok, "https://auth.example/authorize?state=state",
       %{
         transaction_id: "transaction-id",
         code_verifier: String.duplicate("a", 64),
         state_param: "trello-state-0123456789abcdefghijkl",
         issuer: "https://auth.example",
         require_issuer: true,
         redirect_uri: params.redirect_uri
       }}
    end

    def abort("transaction-id"), do: :ok

    def validate_callback(response, transaction) do
      send(self(), {:callback_validated, response, transaction})

      if response["state"] == transaction.state_param,
        do: {:ok, response["code"]},
        else: {:error, :state_mismatch}
    end

    def exchange_code(params) do
      send(self(), {:code_exchanged, params})

      {:ok,
       %{
         access_token: "access",
         refresh_token: "refresh",
         scope: "trello:read",
         expires_in: 3_600
       }}
    end

    def refresh_token("refresh", "dynamic-client", "https://auth.example/token", opts) do
      send(self(), {:token_refreshed, opts})
      {:ok, %{access_token: "refreshed", expires_in: 3_600}}
    end
  end

  setup do
    previous = Application.get_env(:jido_connect_trello, :trello_oauth_flow)
    Application.put_env(:jido_connect_trello, :trello_oauth_flow, FakeFlow)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:jido_connect_trello, :trello_oauth_flow, previous),
        else: Application.delete_env(:jido_connect_trello, :trello_oauth_flow)
    end)

    :ok
  end

  test "default flow discovers, registers, exchanges, and refreshes through ExMCP boundaries" do
    previous = Application.get_env(:jido_connect_trello, :trello_oauth_backend)
    Application.put_env(:jido_connect_trello, :trello_oauth_backend, FakeBackend)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:jido_connect_trello, :trello_oauth_backend, previous),
        else: Application.delete_env(:jido_connect_trello, :trello_oauth_backend)
    end)

    redirect_uri = "https://wayfinder.example/integrations/trello/oauth/callback"

    assert {:ok, started} =
             DefaultFlow.begin("https://mcp.trello.com/v1",
               redirect_uri: redirect_uri,
               scopes: ["trello:read"]
             )

    assert started.state == @state
    assert_received {:registered, %{redirect_uris: [^redirect_uri]}}

    assert {:ok, tokens} =
             DefaultFlow.exchange_code("code", started.transaction,
               callback_params: %{
                 "state" => started.state,
                 "iss" => "https://auth.example"
               }
             )

    assert tokens.oauth_client["client_id"] == "dynamic-client"

    assert_received {:callback_validated, %{"state" => @state, "iss" => "https://auth.example"},
                     _transaction}

    assert {:ok, refreshed} =
             DefaultFlow.refresh_token("refresh", tokens.oauth_client, scope: ["trello:read"])

    assert refreshed.oauth_client == tokens.oauth_client
    assert_received {:token_refreshed, [scope: "trello:read"]}
  end

  test "begins hosted MCP OAuth without returning credential data" do
    assert {:ok, started} =
             OAuth.begin(
               redirect_uri: "https://wayfinder.example/integrations/trello/oauth/callback",
               scopes: ["trello:read"]
             )

    assert started.authorize_url == "https://auth.example/authorize?state=#{@state}"
    assert started.state == @state

    assert started.secret_data == %{
             "redirect_uri" => "https://wayfinder.example/integrations/trello/oauth/callback"
           }

    refute inspect(started) =~ "access-token"
    assert_received {:oauth_begin, _opts}
  end

  test "exchanges and refreshes one code into the fixed Trello endpoint credential" do
    assert {:ok, tokens} =
             OAuth.exchange_code(
               "one-use-code",
               %{
                 "redirect_uri" => "https://wayfinder.example/integrations/trello/oauth/callback"
               },
               callback_params: %{
                 "state" => @state,
                 "iss" => "https://auth.example"
               }
             )

    assert tokens.refresh_token == "trello-refresh-token"
    assert tokens.oauth_client["client_id"] == "trello-client"
    assert tokens.scope == "trello:read trello:write trello:search"
    assert bearer(tokens.mcp_endpoint) == "Bearer trello-access-token"

    assert {:ok, refreshed} =
             OAuth.refresh_token(
               tokens.refresh_token,
               %{"oauth_client" => tokens.oauth_client},
               []
             )

    assert refreshed.refresh_token == "trello-refresh-token"
    assert bearer(refreshed.mcp_endpoint) == "Bearer trello-refreshed-token"
    assert_received {:oauth_exchange, _transaction, _opts}
    assert_received {:oauth_refresh, _client, _opts}
  end

  test "rejects a missing or changed callback state" do
    transaction = %{
      "state_param" => @state,
      "issuer" => "https://auth.example",
      "require_issuer" => true,
      "redirect_uri" => "https://wayfinder.example/integrations/trello/oauth/callback",
      "code_verifier" => String.duplicate("a", 64),
      "client_id" => "dynamic-client",
      "token_endpoint" => "https://auth.example/token",
      "resource" => "https://mcp.trello.com/v1"
    }

    for callback <- [%{"iss" => "https://auth.example"}, %{"state" => "changed"}] do
      assert {:error, :state_mismatch} =
               DefaultFlow.exchange_code("code", transaction, callback_params: callback)
    end
  end

  defp bearer(%{transport: {:streamable_http, opts}}) do
    opts
    |> Keyword.fetch!(:headers)
    |> List.keyfind!("authorization", 0)
    |> elem(1)
  end
end
