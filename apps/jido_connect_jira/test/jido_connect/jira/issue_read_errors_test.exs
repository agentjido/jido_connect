defmodule Jido.Connect.Jira.IssueReadErrorsTest do
  use ExUnit.Case, async: false

  # Errors and diagnostics of `jira.issue.get` and `jira.issue.search` carry
  # neither credentials nor issue content. The responses are recorded ones
  # (`issue_context.2`, `.4` and `.8`; see `Client.IssueReadTest` and
  # `Client.IssueSearchTest`), broken in one place where a case needs a
  # malformed response, so the issue content around the break stays in them.

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Jira
  alias Jido.Connect.TestSupport.LiveSmoke

  @email "reader-267@example.com"
  @api_token "jcl-api-token-267-secret"
  @access_token "jcl-oauth-token-267-secret"
  @jql "project = JCL AND key <= JCL-5 ORDER BY key ASC"

  # Text of the recorded JCL-1 description, from its start and its middle,
  # and of its summary.
  @markers [
    "This issue carries the reference data",
    "Second point with Umlaute",
    "issue with description, comments and due date"
  ]

  defmodule AllowPolicy do
    def authorize(_operation, _input, _context, _connection), do: :ok
  end

  def handle_event(event, _measurements, metadata, test),
    do: send(test, {:telemetry, event, metadata})

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_jira, :jira_req_options)

    Application.put_env(:jido_connect_jira, :jira_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    handler = "jira-issue-read-errors-#{System.unique_integer()}"

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

  test "an issue read with a malformed description" do
    for profile <- [:api_token, :oauth2_user] do
      respond(200, break_description(fixture("issue_context.2")))
      assert_clean_error(invoke(profile, "jira.issue.get", %{issue_key: "JCL-1"}))
    end
  end

  test "an issue read that fails in transport" do
    Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))
    assert_clean_error(invoke(:api_token, "jira.issue.get", %{issue_key: "JCL-1"}))
  end

  test "a search page with a malformed description" do
    page =
      update_in(fixture("issue_context.4"), ["issues"], fn [first | rest] ->
        [break_description(first) | rest]
      end)

    respond(200, page)

    assert %Error.ProviderError{details: %{field: "description"}} =
             assert_clean_error(invoke(:api_token, "jira.issue.search", %{jql: @jql}))
  end

  test "a malformed search page that holds issue content" do
    respond(200, Map.delete(fixture("issue_context.4"), "isLast"))

    assert %Error.ProviderError{details: %{field: "isLast"}} =
             assert_clean_error(invoke(:oauth2_user, "jira.issue.search", %{jql: @jql}))
  end

  test "a search page that Jira rejects" do
    respond(400, fixture("issue_context.8"))

    assert %Error.ProviderError{status: 400} =
             assert_clean_error(
               invoke(:api_token, "jira.issue.search", %{jql: @jql, next_page_token: "token"})
             )
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

  # The recorded description with its first paragraph's content replaced by a
  # map, which is not valid ADF.
  defp break_description(issue) do
    update_in(issue, ["fields", "description", "content"], fn [first | rest] ->
      [Map.put(first, "content", %{}) | rest]
    end)
  end

  defp fixture(name), do: LiveSmoke.fixture!(:jira, name)

  defp respond(status, body) do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(body)
    end)
  end

  defp invoke(profile, action_id, input) do
    runtime =
      Jira.TestRuntime.build(
        profile: profile,
        email: @email,
        api_token: @api_token,
        access_token: @access_token
      )

    lease =
      Connect.CredentialLease.from_connection!(runtime.context.connection, runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    Connect.invoke(Jira, action_id, input,
      context: runtime.context,
      credential_lease: lease,
      policy: AllowPolicy
    )
  end
end
