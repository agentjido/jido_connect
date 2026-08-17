ExUnit.start()

defmodule Jido.Connect.Jira.TestRuntime do
  @moduledoc false

  alias Jido.Connect.{Connection, Context}

  def build(opts \\ []) do
    profile = Keyword.get(opts, :profile, :api_token)

    connection =
      Connection.new!(%{
        id: Keyword.get(opts, :connection_id, "jira_conn_1"),
        provider: :jira,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["read:jira-work", "write:jira-work", "read:jira-configuration"],
        metadata: %{site: Keyword.get(opts, :site, "https://example.atlassian.net")}
      })

    credentials =
      case profile do
        :api_token ->
          %{
            email: Keyword.get(opts, :email, "user@example.com"),
            api_token: Keyword.get(opts, :api_token, "token")
          }

        :oauth2_user ->
          %{access_token: Keyword.get(opts, :access_token, "oauth-token")}
      end

    %{
      provider_client: Keyword.get(opts, :provider_client, Jido.Connect.Jira.MockClient),
      context:
        Context.new!(%{
          tenant_id: "tenant_1",
          actor: %{id: "user_1", type: :app_user},
          connection: connection
        }),
      credentials: credentials
    }
  end
end

defmodule Jido.Connect.Jira.MockClient do
  @moduledoc false

  alias Jido.Connect.Jira.Client.Request

  def get_issue("PROJ-123", %Request{}, _opts) do
    {:ok,
     %{
       key: "PROJ-123",
       id: "10001",
       url: "https://example.atlassian.net/rest/api/3/issue/10001",
       summary: "Test issue",
       status: %{name: "In Progress", id: "3"},
       issue_type: %{name: "Task", id: "10002", subtask: false},
       project: %{key: "PROJ", name: "Project", id: "10000"},
       assignee: %{account_id: "acct-1", display_name: "Test User", active: true},
       priority: %{name: "Medium", id: "3"},
       labels: ["backend"],
       created_at: "2026-05-15T10:00:00.000+0000",
       updated_at: "2026-05-15T12:00:00.000+0000"
     }}
  end

  def get_issue("PROJ-123", %Request{} = request), do: get_issue("PROJ-123", request, [])

  def search_issues("project = PROJ ORDER BY updated DESC", %Request{}, opts) do
    {:ok,
     %{
       issues: [
         %{
           key: "PROJ-123",
           id: "10001",
           summary: "Test issue",
           status: %{name: "In Progress", id: "3"},
           project: %{key: "PROJ", name: "Project", id: "10000"},
           updated_at: "2026-05-15T12:00:00.000+0000"
         }
       ],
       total: 1,
       start_at: Keyword.get(opts, :start_at, 0),
       max_results: Keyword.get(opts, :max_results, 50),
       is_last: true
     }}
  end

  def list_projects(%Request{}, opts) do
    {:ok,
     %{
       projects: [
         %{key: "PROJ", id: "10000", name: "Project Alpha", project_type: "software"},
         %{key: "TEAM", id: "10001", name: "Team Operations", project_type: "business"}
       ],
       total: 2,
       start_at: Keyword.get(opts, :start_at, 0),
       max_results: Keyword.get(opts, :max_results, 50),
       is_last: true
     }}
  end

  def get_project("PROJ", %Request{}) do
    {:ok,
     %{
       key: "PROJ",
       id: "10000",
       name: "Project Alpha",
       project_type: "software",
       style: "classic",
       description: "Main software project for the Alpha product line.",
       lead: %{account_id: "acct-1", display_name: "Alice Nakamura", active: true}
     }}
  end

  def list_field_schemas(%Request{}, _opts) do
    {:ok,
     %{
       fields: [
         %{id: "summary", name: "Summary", key: "summary", custom: false, searchable: true},
         %{id: "assignee", name: "Assignee", key: "assignee", custom: false, searchable: true},
         %{
           id: "customfield_10001",
           name: "Story Points",
           key: "customfield_10001",
           custom: true,
           searchable: true
         }
       ],
       total: 3
     }}
  end

  def create_issue(
        %{
          project: %{key: "PROJ"},
          issuetype: %{name: "Task"},
          summary: "New issue"
        },
        %Request{}
      ) do
    {:ok,
     %{
       key: "PROJ-124",
       id: "10002",
       url: "https://example.atlassian.net/rest/api/3/issue/10002",
       summary: "New issue",
       status: %{name: "To Do", id: "1"},
       issue_type: %{name: "Task", id: "10002", subtask: false},
       project: %{key: "PROJ", name: "Project", id: "10000"},
       labels: [],
       created_at: "2026-05-15T14:00:00.000+0000",
       updated_at: "2026-05-15T14:00:00.000+0000"
     }}
  end

  def update_issue("PROJ-123", _fields, %Request{}), do: {:ok, %{updated: true}}

  def transition_issue("PROJ-123", "21", %Request{}, _opts),
    do: {:ok, %{transitioned: true}}

  def assign_issue("PROJ-123", "acct-1", %Request{}), do: {:ok, %{assigned: true}}

  def add_comment("PROJ-123", _body_text, %Request{}) do
    {:ok,
     %{
       id: "20010",
       body: "Test comment body",
       created_at: "2026-05-15T14:00:00.000+0000"
     }}
  end
end

# Ensure Req.Test.Ownership is running so that client tests can run without the
# full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
