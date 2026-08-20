defmodule Jido.Connect.Confluence.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Confluence.{ADF, Client}
  alias Jido.Connect.Confluence.Client.{Request, Transport}

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_confluence, :confluence_req_options)

    Application.put_env(
      :jido_connect_confluence,
      :confluence_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_confluence, :confluence_req_options, previous)
      else
        Application.delete_env(:jido_connect_confluence, :confluence_req_options)
      end
    end)

    :ok
  end

  test "binds Basic credentials only to a normalized Confluence Cloud tenant" do
    assert {:ok, request} =
             Request.new(connection("https://example.atlassian.net"), credentials())

    assert request.endpoint == "https://example.atlassian.net/wiki"

    assert Request.url(request, "/api/v2/spaces") ==
             "https://example.atlassian.net/wiki/api/v2/spaces"

    http_request = Transport.request(request)

    assert http_request.options.base_url == "https://example.atlassian.net/wiki"

    assert http_request.headers["authorization"] == [
             "Basic " <> Base.encode64("account@example.com:secret-api-token")
           ]

    assert Request.account(request) == "account-1"
    refute inspect(request) =~ "account@example.com"
    refute inspect(request) =~ "secret-api-token"

    assert {:ok, explicit_default_port} =
             Request.new(connection("https://EXAMPLE.atlassian.net:443/wiki/"), credentials())

    assert explicit_default_port.endpoint == "https://example.atlassian.net/wiki"
  end

  test "rejects attacker HTTPS targets and arbitrary endpoint metadata" do
    invalid_sites = [
      "http://example.atlassian.net/wiki",
      "https://attacker.example/wiki",
      "https://example.atlassian.net.attacker.example/wiki",
      "https://atlassian.net/wiki",
      "https://user:password@example.atlassian.net/wiki",
      "https://example.atlassian.net:444/wiki",
      "https://example.atlassian.net/wiki?token=secret",
      "https://example.atlassian.net/wiki#fragment",
      "https://example.atlassian.net/other",
      "not-a-url"
    ]

    for site <- invalid_sites do
      assert {:error, %Error.AuthError{reason: :invalid_confluence_site_url}} =
               Request.new(connection(site), credentials())
    end

    arbitrary_metadata =
      Connection.new!(%{
        id: "conn-arbitrary",
        provider: :confluence,
        profile: :api_token,
        tenant_id: "tenant-1",
        owner_type: :app_user,
        owner_id: "owner-1",
        subject: %{id: "account-1"},
        status: :connected,
        scopes: [],
        metadata: %{api_endpoint: "https://attacker.example/wiki"}
      })

    assert {:error, %Error.AuthError{reason: :confluence_site_url_required}} =
             Request.new(arbitrary_metadata, credentials())

    assert {:error, %Error.AuthError{reason: :confluence_connection_required}} =
             Request.new(connection("https://example.atlassian.net/wiki", :jira), credentials())

    assert {:error, %Error.AuthError{reason: :unsupported_confluence_auth_profile}} =
             Request.new(
               connection("https://example.atlassian.net/wiki", :confluence, :oauth2),
               credentials()
             )

    assert {:error, %Error.AuthError{reason: :confluence_credentials_required}} =
             Request.new(connection("https://example.atlassian.net/wiki"), %{
               email: "account@example.com"
             })
  end

  test "uses exact space and paginated page list routes with strict normalized results" do
    request = request_context()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/spaces"
      assert URI.decode_query(conn.query_string) == %{"keys" => "OPS", "limit" => "2"}
      Req.Test.json(conn, fixture!("space.json"))
    end)

    assert {:ok, space} = Client.get_space(%{key: "OPS"}, request)

    assert space == %{
             kind: "confluence_space",
             account: "account-1",
             id: "space-1",
             key: "OPS",
             name: "Operations",
             type: "global",
             status: "current",
             homepage_id: "home-1",
             url: "https://example.atlassian.net/wiki/spaces/OPS"
           }

    expect_space_resolution()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/spaces/space-1/pages"

      assert URI.decode_query(conn.query_string) == %{
               "cursor" => "cursor-1",
               "limit" => "1"
             }

      Req.Test.json(conn, fixture!("pages.json"))
    end)

    assert {:ok, result} =
             Client.list_pages(%{space_key: "OPS", cursor: "cursor-1", limit: 1}, request)

    assert result.kind == "confluence_pages"
    assert result.space == %{id: "space-1", key: "OPS"}
    assert result.count == 1
    assert result.limit == 1
    assert result.next_cursor == "next-1"

    assert [item] = result.items
    assert item.id == "page-1"
    assert item.space_id == "space-1"
    assert item.version == 4
    assert item.url == "https://example.atlassian.net/wiki/spaces/OPS/pages/page-1/Runbook"
  end

  test "gets ADF page text and reports character truncation" do
    request = request_context()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/pages/page-1"
      assert URI.decode_query(conn.query_string) == %{"body-format" => "atlas_doc_format"}
      Req.Test.json(conn, fixture!("page.json"))
    end)

    assert {:ok, result} = Client.get_page(%{id: "page-1", max_characters: 8}, request)
    assert result.kind == "confluence_page"
    assert result.id == "page-1"
    assert result.version == 4
    assert result.revision_id == "4"
    assert result.text == "Runbook\n"
    assert result.character_count == String.length("Runbook\nFirst line\nSecond line")
    assert result.truncated
  end

  test "converts bounded Markdown to ADF without accepting unsafe links" do
    markdown = """
    # Runbook

    First line
    second line

    - First item
    - [Safe](https://example.com/path)

    > Quoted text

    ```elixir
    :ok
    ```

    ---

    [Unsafe](http://example.com)
    """

    assert {:ok, adf} = ADF.from_markdown(markdown)

    assert Enum.map(adf["content"], & &1["type"]) == [
             "heading",
             "paragraph",
             "bulletList",
             "blockquote",
             "codeBlock",
             "rule",
             "paragraph"
           ]

    encoded = Jason.encode!(adf)
    assert encoded =~ "https://example.com/path"
    refute encoded =~ ~s(\"href\":\"http://example.com\")
    assert {:ok, text} = ADF.to_text(adf)
    assert text =~ "First line\nsecond line"
    assert text =~ "- Safe"
    assert text =~ "Unsafe"
    assert :error = ADF.to_text(%{"type" => "doc", "content" => [%{"type" => "unknown"}]})
  end

  test "creates a page with the exact ADF request body and no automatic mutation retry" do
    request = request_context()
    expect_space_resolution()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/pages"

      assert json_body(conn) == %{
               "spaceId" => "space-1",
               "status" => "current",
               "title" => "Runbook",
               "parentId" => "parent-1",
               "body" => %{
                 "representation" => "atlas_doc_format",
                 "value" => Jason.encode!(elem(ADF.from_markdown("# Runbook"), 1))
               }
             }

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(page_response(1))
    end)

    assert {:ok, result} =
             Client.create_page(
               %{
                 title: "Runbook",
                 space_key: "OPS",
                 markdown: "# Runbook",
                 parent_id: "parent-1"
               },
               request
             )

    assert result == %{
             kind: "confluence_page_effect",
             effect: "create",
             submitted: true,
             page: %{id: "page-1", title: "Runbook", space_id: "space-1", version: 1}
           }

    assert Transport.request(request, mutation?: true).options.retry == false
  end

  test "updates with optimistic version and space checks" do
    request = request_context()
    expect_current_page(4)
    expect_space_resolution()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/wiki/api/v2/pages/page-1"

      assert json_body(conn) == %{
               "id" => "page-1",
               "status" => "current",
               "title" => "Remote title",
               "body" => %{
                 "representation" => "atlas_doc_format",
                 "value" => Jason.encode!(elem(ADF.from_markdown("New text"), 1))
               },
               "version" => %{"number" => 5, "message" => "Sync from source"}
             }

      Req.Test.json(conn, page_response(5, "Remote title"))
    end)

    assert {:ok, %{effect: "update", page: %{version: 5}}} =
             Client.update_page(
               %{
                 id: "page-1",
                 space_key: "OPS",
                 markdown: "New text",
                 last_pushed_version: 4,
                 version_message: "Sync from source"
               },
               request
             )
  end

  test "stops on version drift, while force uses the remote next version" do
    request = request_context()
    expect_current_page(6)

    assert {:error,
            %Error.ProviderError{
              provider: :confluence,
              reason: :version_conflict,
              delivery: :response_received,
              mutation?: false,
              details: %{last_pushed_version: 4, remote_version: 6}
            }} =
             Client.update_page(
               %{id: "page-1", space_key: "OPS", markdown: "New text", last_pushed_version: 4},
               request
             )

    expect_current_page(6)
    expect_space_resolution()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert get_in(json_body(conn), ["version", "number"]) == 7
      Req.Test.json(conn, page_response(7, "Remote title"))
    end)

    assert {:ok, %{page: %{version: 7}}} =
             Client.update_page(
               %{
                 id: "page-1",
                 space_key: "OPS",
                 markdown: "New text",
                 last_pushed_version: 4,
                 force: true
               },
               request
             )
  end

  test "force never bypasses the remote space check" do
    request = request_context()
    expect_current_page(6, "other-space")
    expect_space_resolution()

    assert {:error,
            %Error.ProviderError{
              reason: :space_mismatch,
              delivery: :response_received,
              mutation?: false
            }} =
             Client.update_page(
               %{
                 id: "page-1",
                 space_key: "OPS",
                 markdown: "New text",
                 last_pushed_version: 4,
                 force: true
               },
               request
             )
  end

  test "deletes one page with destructive effect and mutation uncertainty" do
    request = request_context()

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/wiki/api/v2/pages/page-1"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok,
            %{
              kind: "confluence_page_effect",
              effect: "delete",
              submitted: true,
              page: %{id: "page-1"}
            }} = Client.delete_page(%{id: "page-1"}, request)

    test_pid = self()

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, :delete_attempt)
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error,
            %Error.ProviderError{
              delivery: :sent_outcome_unknown,
              mutation?: true,
              provider_idempotency?: false
            } = error} = Client.delete_page(%{id: "page-1"}, request)

    assert Error.retry_guidance(error) == :do_not_retry
    assert_receive :delete_attempt
    refute_receive :delete_attempt, 50
  end

  test "turns malformed successes and provider failures into strict redacted errors" do
    request = request_context()

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"results" => "not-a-list", "api_token" => "success-secret"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :confluence,
              reason: :invalid_response,
              delivery: :response_received,
              mutation?: false
            } = invalid} = Client.get_space(%{key: "OPS"}, request)

    rendered_invalid = inspect(invalid) <> inspect(Error.to_map(invalid))
    refute rendered_invalid =~ "success-secret"

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{
        "message" => "secret-api-token was rejected",
        "api_token" => "secret-api-token"
      })
    end)

    assert {:error,
            %Error.ProviderError{
              status: 401,
              delivery: :rejected,
              mutation?: true,
              provider_idempotency?: false
            } = rejected} = Client.delete_page(%{id: "page-1"}, request)

    rendered_rejected = inspect(rejected) <> inspect(Error.to_map(rejected))
    refute rendered_rejected =~ "secret-api-token"
    assert Error.retry_guidance(rejected) == :do_not_retry

    expect_space_resolution()

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"id" => "page-1", "api_token" => "mutation-secret"})
    end)

    assert {:error,
            %Error.ProviderError{
              reason: :invalid_response,
              delivery: :response_received,
              mutation?: true
            } = malformed_mutation} =
             Client.create_page(%{title: "Runbook", space_key: "OPS", markdown: "text"}, request)

    refute inspect(malformed_mutation) <> inspect(Error.to_map(malformed_mutation)) =~
             "mutation-secret"

    assert Error.retry_guidance(malformed_mutation) == :do_not_retry
  end

  test "validates raw attrs at every public client boundary" do
    request = request_context()

    calls = [
      fn -> Client.get_space(%{key: ""}, request) end,
      fn -> Client.list_pages(%{space_key: "OPS", limit: 0}, request) end,
      fn -> Client.get_page(%{id: "page-1", max_characters: 0}, request) end,
      fn -> Client.create_page(%{title: "", space_key: "OPS", markdown: "text"}, request) end,
      fn ->
        Client.update_page(
          %{id: "page-1", space_key: "OPS", markdown: "text", last_pushed_version: 0},
          request
        )
      end,
      fn -> Client.delete_page(%{id: ""}, request) end
    ]

    for call <- calls do
      assert {:error, %Error.ValidationError{reason: :invalid_confluence_input}} = call.()
    end
  end

  defp request_context do
    {:ok, request} =
      Request.new(connection("https://example.atlassian.net/wiki"), credentials())

    request
  end

  defp connection(site_url, provider \\ :confluence, profile \\ :api_token) do
    Connection.new!(%{
      id: "conn-1",
      provider: provider,
      profile: profile,
      tenant_id: "tenant-1",
      owner_type: :app_user,
      owner_id: "owner-1",
      subject: %{id: "account-1"},
      status: :connected,
      scopes: [],
      metadata: %{site_url: site_url}
    })
  end

  defp credentials do
    %{email: "account@example.com", api_token: "secret-api-token"}
  end

  defp fixture!(name) do
    [__DIR__, "..", "..", "fixtures", name]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp expect_space_resolution do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/spaces"
      assert URI.decode_query(conn.query_string) == %{"keys" => "OPS", "limit" => "2"}
      Req.Test.json(conn, fixture!("space.json"))
    end)
  end

  defp expect_current_page(version, space_id \\ "space-1") do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/pages/page-1"
      assert conn.query_string == ""

      conn
      |> Req.Test.json(
        page_response(version, "Remote title", space_id)
        |> Map.drop(["body"])
      )
    end)
  end

  defp page_response(version, title \\ "Runbook", space_id \\ "space-1") do
    fixture!("page.json")
    |> Map.put("title", title)
    |> Map.put("spaceId", space_id)
    |> Map.put("version", %{"number" => version})
  end

  defp json_body(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end
end
