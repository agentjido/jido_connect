defmodule Jido.Connect.Jira.CommentListActionTest do
  use ExUnit.Case, async: false

  # `jira.issue.comment.list` through the runtime, against the responses that
  # the live test "lists the prepared issue's comments across two pages, the
  # restricted one included" recorded (see `Client.CommentListTest`):
  # `comment_list` holds four comments, `comment_list.4` the last page and
  # `comment_list.6` Jira's 404 answer for a missing issue.
  #
  # The test site cannot be made to answer 401, 403, 429 or 5xx: an unknown
  # identity gets the same 404 as a missing issue. Those cases send the
  # recorded 404 body with only the status changed.

  alias Jido.Connect
  alias Jido.Connect.{Connection, Context, Error}
  alias Jido.Connect.Jira
  alias Jido.Connect.TestSupport.LiveSmoke

  @email "reader-268@example.com"
  @api_token "jcl-api-token-268-secret"
  @access_token "jcl-oauth-token-268-secret"

  # Text from the four recorded comments.
  @markers [
    "First comment with a list",
    "Comment list item one",
    "Restricted to the role",
    "Comment with an embedded image",
    "Line 01 of the long live-test text"
  ]

  def handle_event(event, _measurements, metadata, test),
    do: send(test, {:telemetry, event, metadata})

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_jira, :jira_req_options)

    Application.put_env(:jido_connect_jira, :jira_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    handler = "jira-comment-list-#{System.unique_integer()}"

    :telemetry.attach_many(
      handler,
      for(phase <- [:start, :stop, :exception], do: [:jido, :connect, :invoke, phase]),
      &__MODULE__.handle_event/4,
      self()
    )

    on_exit(fn ->
      :telemetry.detach(handler)

      if previous do
        Application.put_env(:jido_connect_jira, :jira_req_options, previous)
      else
        Application.delete_env(:jido_connect_jira, :jira_req_options)
      end
    end)
  end

  describe "output" do
    test "returns the page with plain comment maps that encode as JSON" do
      respond(200, fixture("comment_list"), fn conn ->
        assert conn.query_params == %{
                 "startAt" => "0",
                 "maxResults" => "4",
                 "orderBy" => "created"
               }
      end)

      assert {:ok, page} = invoke(:api_token, %{issue_key: "JCL-1", max_results: 4})

      assert %{
               issue: "JCL-1",
               start_at: 0,
               max_results: 4,
               total: 54,
               is_last: false,
               next_start_at: 4,
               comments: [first, restricted, image, long]
             } = page

      assert %{id: "42672", author: %{account_id: "account-1"} = author} = first
      refute is_struct(author)
      assert %{visibility: %{"type" => "role"}} = restricted
      refute Map.has_key?(first, :visibility)
      assert %{body_unsupported_nodes: ["mediaSingle"]} = image
      assert %{author: %{display_name: "Person 2"}} = long
      assert {:ok, _json} = Jason.encode(page)
    end

    test "leaves next_start_at out of the last page" do
      respond(200, fixture("comment_list.4"))

      assert {:ok, %{is_last: true, start_at: 52} = page} =
               invoke(:oauth2_user, %{issue_key: "JCL-1", start_at: 52, max_results: 2})

      refute Map.has_key?(page, :next_start_at)
    end

    test "sends maxResults=50 and startAt=0 by default" do
      respond(200, fixture("comment_list"), fn conn ->
        assert conn.query_params["maxResults"] == "50"
        assert conn.query_params["startAt"] == "0"
      end)

      assert {:ok, %{issue: "46096"}} = invoke(:api_token, %{issue_key: "46096"})
    end
  end

  describe "gates before HTTP" do
    test "page sizes 0 and 101 and a negative offset fail input validation" do
      for input <- [%{max_results: 0}, %{max_results: 101}, %{start_at: -1}] do
        assert {:error, %Error.ValidationError{reason: :input}} =
                 invoke(:api_token, Map.put(input, :issue_key, "JCL-1"))
      end
    end

    test "a missing read scope stops the call" do
      assert {:error,
              %Error.AuthError{reason: :missing_scopes, missing_scopes: ["read:jira-work"]}} =
               invoke(:api_token, %{issue_key: "JCL-1"}, scopes: ["write:jira-work"])
    end

    test "a denied policy stops the call" do
      assert {:error, %Error.AuthError{reason: :policy_denied}} =
               invoke(:api_token, %{issue_key: "JCL-1"},
                 policy: fn _operation, _input, _context, _connection -> :deny end
               )
    end
  end

  describe "errors" do
    test "provider statuses become normalized errors without content or credentials" do
      body = fixture("comment_list.6")

      for {status, profile} <- [
            {404, :api_token},
            {401, :api_token},
            {403, :oauth2_user},
            {429, :api_token},
            {500, :oauth2_user},
            {503, :api_token}
          ] do
        respond(status, body)

        assert %Error.ProviderError{
                 provider: :jira,
                 status: ^status,
                 reason: :http_error,
                 details: %{
                   message: "Issue does not exist or you do not have permission to see it."
                 }
               } = assert_clean_error(invoke(profile, %{issue_key: "JCL-1"}))
      end
    end

    test "a transport failure" do
      Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

      assert %Error.ProviderError{reason: :request_error} =
               assert_clean_error(invoke(:api_token, %{issue_key: "JCL-1"}))
    end

    test "invalid pages that hold comment content" do
      # The recorded first page broken in one place: no total, an empty
      # non-final page and a comment body that is not valid ADF.
      [first | rest] = fixture("comment_list")["comments"]

      broken =
        update_in(first, ["body", "content"], fn [paragraph | others] ->
          [Map.put(paragraph, "content", %{}) | others]
        end)

      for {body, field} <- [
            {Map.delete(fixture("comment_list"), "total"), "total"},
            {Map.put(fixture("comment_list"), "comments", []), "comments"},
            {Map.put(fixture("comment_list"), "comments", [broken | rest]), "body"}
          ] do
        respond(200, body)

        assert %Error.ProviderError{reason: :invalid_response, details: %{field: ^field}} =
                 assert_clean_error(invoke(:oauth2_user, %{issue_key: "JCL-1"}))
      end
    end
  end

  defp assert_clean_error(result) do
    assert {:error, error} = result
    assert_receive {:telemetry, [:jido, :connect, :invoke, :stop], metadata}
    assert metadata.status == :error

    texts = [
      inspect(error),
      inspect(Error.to_map(error)),
      Exception.message(error),
      inspect(metadata)
    ]

    secrets = [@email, @api_token, @access_token, Base.encode64("#{@email}:#{@api_token}")]

    for text <- texts, value <- secrets ++ @markers do
      refute text =~ value
    end

    error
  end

  defp fixture(name), do: LiveSmoke.fixture!(:jira, name)

  defp respond(status, body, check \\ fn _conn -> :ok end) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path =~ ~r{/rest/api/3/issue/[^/]+/comment$}
      check.(conn)

      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(body)
    end)
  end

  defp invoke(profile, input, opts \\ []) do
    runtime =
      Jira.TestRuntime.build(
        profile: profile,
        email: @email,
        api_token: @api_token,
        access_token: @access_token
      )

    context = with_scopes(runtime.context, Keyword.get(opts, :scopes))

    lease =
      Connect.CredentialLease.from_connection!(context.connection, runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    Connect.invoke(Jira, "jira.issue.comment.list", input,
      context: context,
      credential_lease: lease,
      policy: Keyword.get(opts, :policy, fn _operation, _input, _context, _connection -> :ok end)
    )
  end

  defp with_scopes(context, nil), do: context

  defp with_scopes(%Context{connection: connection} = context, scopes) do
    %{context | connection: Connection.new!(%{Map.from_struct(connection) | scopes: scopes})}
  end
end
