defmodule Jido.Connect.Jira.Handlers.Actions.ListCommentsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Jira
  alias Jido.Connect.Jira.Client.Request
  alias Jido.Connect.Jira.Handlers.Actions.ListComments

  defmodule RecordingClient do
    @moduledoc false

    def list_comments(issue_key, %Request{} = request, opts) do
      send(self(), {:list_comments, issue_key, request.connection.id, Enum.sort(opts)})

      {:ok,
       %{
         issue: issue_key,
         comments: [],
         start_at: Keyword.get(opts, :start_at, 0),
         max_results: Keyword.get(opts, :max_results, 50),
         total: 0,
         is_last: true,
         next_start_at: nil
       }}
    end
  end

  defmodule FailingClient do
    @moduledoc false

    def list_comments(_issue_key, %Request{}, _opts) do
      {:error, Error.provider("Jira comment list request failed", provider: :jira, status: 404)}
    end
  end

  test "passes the issue reference and the paging input to the injected client" do
    runtime = Jira.TestRuntime.build(provider_client: RecordingClient)

    assert {:ok, %{issue: "JCL-1", start_at: 2, max_results: 2}} =
             ListComments.run(%{issue_key: "JCL-1", start_at: 2, max_results: 2}, runtime)

    assert_received {:list_comments, "JCL-1", "jira_conn_1", [max_results: 2, start_at: 2]}
  end

  test "leaves the paging defaults to the client" do
    runtime = Jira.TestRuntime.build(provider_client: RecordingClient)

    assert {:ok, %{issue: "JCL-1"}} = ListComments.run(%{issue_key: "JCL-1"}, runtime)
    assert_received {:list_comments, "JCL-1", "jira_conn_1", []}
  end

  test "returns the client's error" do
    runtime = Jira.TestRuntime.build(provider_client: FailingClient)

    assert {:error, %Error.ProviderError{status: 404}} =
             ListComments.run(%{issue_key: "JCL-1"}, runtime)
  end

  test "the generated action sends its declared defaults through the injected client" do
    runtime = Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(runtime.context.connection, runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert {:ok, page} =
             Connect.invoke(Jira, "jira.issue.comment.list", %{issue_key: "46096"},
               context: runtime.context,
               credential_lease: lease,
               policy: fn _operation, _input, _context, _connection -> :ok end,
               provider_client: RecordingClient
             )

    assert page == %{
             issue: "46096",
             comments: [],
             start_at: 0,
             max_results: 50,
             total: 0,
             is_last: true
           }

    assert_received {:list_comments, "46096", "jira_conn_1", [max_results: 50, start_at: 0]}
  end
end
