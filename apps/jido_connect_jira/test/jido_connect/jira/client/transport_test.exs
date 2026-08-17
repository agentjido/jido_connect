defmodule Jido.Connect.Jira.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Jira.Client
  alias Jido.Connect.Jira.Client.{Request, Transport}

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_jira, :jira_req_options)
    Application.put_env(:jido_connect_jira, :jira_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_jira, :jira_req_options, previous)
      else
        Application.delete_env(:jido_connect_jira, :jira_req_options)
      end
    end)
  end

  test "API token requests use Basic authentication and the connection site" do
    request_context =
      jira_request(
        "conn_a",
        "https://a.atlassian.net/",
        "a@example.com",
        "token-a"
      )

    request = Transport.request(request_context)

    assert request.options.base_url == "https://a.atlassian.net"
    assert request.headers["authorization"] == [basic("a@example.com", "token-a")]
    assert request.headers["accept"] == ["application/json"]
    refute inspect(request_context) =~ "a@example.com"
    refute inspect(request_context) =~ "token-a"
  end

  test "OAuth requests use Bearer authentication and the connection cloud endpoint" do
    connection =
      connection(
        "oauth_conn",
        :oauth2_user,
        %{cloud_endpoint: "https://api.atlassian.com/ex/jira/cloud-123"}
      )

    assert {:ok, request_context} = Request.new(connection, %{access_token: "oauth-token"})
    request = Transport.request(request_context)

    assert request.options.base_url == "https://api.atlassian.com/ex/jira/cloud-123"
    assert request.headers["authorization"] == ["Bearer oauth-token"]
  end

  test "OAuth operations preserve the cloud endpoint path" do
    connection =
      connection(
        "oauth_conn",
        :oauth2_user,
        %{cloud_endpoint: "https://api.atlassian.com/ex/jira/cloud-123"}
      )

    assert {:ok, request_context} = Request.new(connection, %{access_token: "oauth-token"})

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/ex/jira/cloud-123/rest/api/3/issue/PROJ-123"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer oauth-token"]
      Req.Test.json(conn, %{"key" => "PROJ-123", "fields" => %{}})
    end)

    assert {:ok, %{key: "PROJ-123"}} = Client.get_issue("PROJ-123", request_context)
  end

  test "two concurrent connections keep separate endpoints and identities" do
    contexts = [
      jira_request("conn_a", "https://a.atlassian.net", "a@example.com", "token-a"),
      jira_request("conn_b", "https://b.atlassian.net", "b@example.com", "token-b")
    ]

    results =
      contexts
      |> Task.async_stream(
        fn request_context ->
          request = Transport.request(request_context)

          {
            request_context.connection.id,
            request.options.base_url,
            request.headers["authorization"]
          }
        end,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.sort()

    assert results == [
             {"conn_a", "https://a.atlassian.net", [basic("a@example.com", "token-a")]},
             {"conn_b", "https://b.atlassian.net", [basic("b@example.com", "token-b")]}
           ]
  end

  test "request context requires a connection endpoint and profile fields" do
    assert {:error, %Error.AuthError{reason: :jira_endpoint_required}} =
             Request.new(connection("missing_site", :api_token, %{}), %{
               email: "user@example.com",
               api_token: "token"
             })

    assert {:error,
            %Error.AuthError{
              reason: :jira_credentials_required,
              details: %{missing_fields: [:email]}
            }} =
             Request.new(connection("missing_email", :api_token, %{site: "https://a.test"}), %{
               api_token: "token"
             })
  end

  test "request context rejects plaintext credential endpoints" do
    assert {:error,
            %Error.AuthError{
              reason: :insecure_jira_endpoint,
              connection_id: "plaintext_site"
            }} =
             Request.new(
               connection("plaintext_site", :api_token, %{site: "http://jira.example.test"}),
               %{email: "user@example.com", api_token: "token"}
             )
  end

  test "handle_error_response normalizes HTTP error bodies" do
    assert {:error, %Error.ProviderError{provider: :jira, reason: :http_error, status: 400}} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"errorMessages" => ["Bad request"]}}}
             )
  end

  test "handle_error_response extracts Jira error messages" do
    assert {:error, %Error.ProviderError{details: %{message: "Field is required"}}} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"errorMessages" => ["Field is required"]}}}
             )
  end

  test "handle_error_response handles request errors" do
    assert {:error, %Error.ProviderError{provider: :jira}} =
             Transport.handle_error_response({:error, :timeout})
  end

  test "invalid_success_response returns a provider error" do
    assert {:error, %Error.ProviderError{provider: :jira, reason: :invalid_response}} =
             Transport.invalid_success_response("test message", %{foo: "bar"})
  end

  defp jira_request(id, site, email, api_token) do
    connection = connection(id, :api_token, %{site: site})
    {:ok, request} = Request.new(connection, %{email: email, api_token: api_token})
    request
  end

  defp connection(id, profile, metadata) do
    Connection.new!(%{
      id: id,
      provider: :jira,
      profile: profile,
      tenant_id: "tenant_1",
      owner_type: :app_user,
      owner_id: "user_1",
      status: :connected,
      scopes: ["read:jira-work"],
      metadata: metadata
    })
  end

  defp basic(email, token), do: "Basic " <> Base.encode64("#{email}:#{token}")
end
