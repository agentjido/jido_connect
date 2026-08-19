defmodule Jido.Connect.Bitbucket.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Bitbucket.Client
  alias Jido.Connect.Bitbucket.Client.{Request, Transport}

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_bitbucket, :bitbucket_req_options)

    Application.put_env(
      :jido_connect_bitbucket,
      :bitbucket_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_bitbucket, :bitbucket_req_options, previous)
      else
        Application.delete_env(:jido_connect_bitbucket, :bitbucket_req_options)
      end
    end)

    :ok
  end

  test "defaults to the official HTTPS v2 endpoint and uses Basic auth" do
    assert {:ok, request_context} =
             Request.new(connection("conn-1", %{}), %{
               email: "account@example.com",
               api_token: "secret-api-token"
             })

    request = Transport.request(request_context)

    assert request.options.base_url == "https://api.bitbucket.org/2.0"

    assert request.headers["authorization"] == [
             "Basic " <> Base.encode64("account@example.com:secret-api-token")
           ]

    assert request.headers["accept"] == ["application/json"]
    assert Request.account(request_context) == "account-1"
    refute inspect(request_context) =~ "account@example.com"
    refute inspect(request_context) =~ "secret-api-token"
  end

  test "validates provider identity, HTTPS endpoints, and credentials" do
    assert {:error, %Error.AuthError{reason: :bitbucket_connection_required}} =
             Request.new(connection("wrong-provider", %{}, :github), %{
               email: "account@example.com",
               api_token: "token"
             })

    for endpoint <- [
          "http://api.bitbucket.org/2.0",
          "https://attacker.example/2.0",
          "https://user:password@api.bitbucket.org/2.0",
          "https://api.bitbucket.org/2.0?token=secret",
          "not-a-url"
        ] do
      assert {:error, %Error.AuthError{reason: :invalid_bitbucket_endpoint}} =
               Request.new(connection("bad-endpoint", %{api_endpoint: endpoint}), %{
                 email: "account@example.com",
                 api_token: "token"
               })
    end

    assert {:error,
            %Error.AuthError{
              reason: :bitbucket_credentials_required,
              details: %{missing_fields: [:api_token]}
            }} =
             Request.new(connection("missing-token", %{}), %{email: "account@example.com"})

    assert {:error, %Error.AuthError{reason: :unsupported_bitbucket_auth_profile}} =
             Request.new(connection("wrong-profile", %{}, :bitbucket, :oauth2), %{
               email: "account@example.com",
               api_token: "token"
             })
  end

  test "sends the exact list request and returns the strict normalized result" do
    request_context = request_context()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2.0/repositories/acme/widgets/pullrequests"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "pagelen" => "20",
               "state" => "MERGED"
             }

      assert Plug.Conn.get_req_header(conn, "authorization") == [
               "Basic " <> Base.encode64("account@example.com:secret-api-token")
             ]

      Req.Test.json(conn, pull_request_page())
    end)

    assert {:ok, result} =
             Client.list_pull_requests("acme", "widgets", request_context,
               state: "merged",
               limit: 20,
               page: 2
             )

    assert result == %{
             kind: "pull_requests",
             account: "account-1",
             workspace: "acme",
             repository: "widgets",
             state: "merged",
             count: 1,
             page: 2,
             page_length: 20,
             total: 3,
             next_page:
               "https://api.bitbucket.org/2.0/repositories/acme/widgets/pullrequests?page=3",
             items: [
               %{
                 id: 42,
                 title: "Add reviewed action",
                 state: "merged",
                 source_branch: "feature/reader",
                 destination_branch: "main",
                 author: %{id: "{author-1}", display_name: "Ada Lovelace"},
                 draft: false,
                 created_at: "2026-08-18T10:00:00Z",
                 updated_at: "2026-08-19T10:00:00Z",
                 url: "https://bitbucket.org/acme/widgets/pull-requests/42"
               }
             ]
           }
  end

  test "rejects malformed success payloads with normalized redacted errors" do
    request_context = request_context()

    malformed_payloads = [
      %{"values" => "not-a-list", "api_token" => "success-secret"},
      pull_request_page(%{"links" => %{"html" => %{"href" => "http://unsafe.test/pr/42"}}}),
      pull_request_page(%{"author" => %{"uuid" => nil, "display_name" => "Ada"}}),
      Map.put(pull_request_page(), "next", "http://unsafe.test/page=3")
    ]

    for payload <- malformed_payloads do
      Req.Test.expect(__MODULE__, fn conn -> Req.Test.json(conn, payload) end)

      assert {:error,
              %Error.ProviderError{
                provider: :bitbucket,
                reason: :invalid_response,
                delivery: :response_received
              } = error} =
               Client.list_pull_requests("acme", "widgets", request_context,
                 state: "merged",
                 limit: 20,
                 page: 2
               )

      rendered = inspect(error) <> inspect(Error.to_map(error))
      refute rendered =~ "success-secret"
      refute rendered =~ "unsafe.test"
    end
  end

  test "normalizes provider and transport errors without response secrets" do
    request_context = request_context()

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{
        "error" => %{"message" => "token secret-api-token was rejected"},
        "api_token" => "secret-api-token"
      })
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :bitbucket,
              reason: :http_error,
              status: 401,
              delivery: :rejected
            } = error} =
             Client.list_pull_requests("acme", "widgets", request_context)

    rendered = inspect(error) <> inspect(Error.to_map(error))
    refute rendered =~ "secret-api-token"
    assert error.details.body_summary.type == :map

    assert {:error,
            %Error.ProviderError{
              provider: :bitbucket,
              reason: :request_error,
              delivery: :sent_outcome_unknown
            }} = Transport.handle_error_response({:error, {:timeout, "secret-api-token"}})
  end

  defp request_context do
    {:ok, request} =
      Request.new(connection("conn-1", %{}), %{
        email: "account@example.com",
        api_token: "secret-api-token"
      })

    request
  end

  defp connection(id, metadata, provider \\ :bitbucket, profile \\ :api_token) do
    Connection.new!(%{
      id: id,
      provider: provider,
      profile: profile,
      tenant_id: "tenant-1",
      owner_type: :app_user,
      owner_id: "owner-1",
      subject: %{id: "account-1"},
      status: :connected,
      scopes: ["read:pullrequest:bitbucket"],
      metadata: metadata
    })
  end

  defp pull_request_page(overrides \\ %{}) do
    item =
      Map.merge(
        %{
          "id" => 42,
          "title" => "Add reviewed action",
          "state" => "MERGED",
          "source" => %{"branch" => %{"name" => "feature/reader"}},
          "destination" => %{"branch" => %{"name" => "main"}},
          "author" => %{"uuid" => "{author-1}", "display_name" => "Ada Lovelace"},
          "draft" => false,
          "created_on" => "2026-08-18T10:00:00Z",
          "updated_on" => "2026-08-19T10:00:00Z",
          "links" => %{
            "html" => %{
              "href" => "https://bitbucket.org/acme/widgets/pull-requests/42"
            }
          }
        },
        overrides
      )

    %{
      "size" => 3,
      "page" => 2,
      "pagelen" => 20,
      "next" => "https://api.bitbucket.org/2.0/repositories/acme/widgets/pullrequests?page=3",
      "values" => [item]
    }
  end
end
