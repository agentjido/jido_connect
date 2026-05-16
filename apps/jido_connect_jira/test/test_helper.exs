ExUnit.start()

defmodule Jido.Connect.Jira.MockClient do
  @moduledoc false

  def get_issue("PROJ-123", "token") do
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

  def search_issues("project = PROJ ORDER BY updated DESC", "token",
        max_results: 50,
        start_at: 0
      ) do
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
       start_at: 0,
       max_results: 50
     }}
  end

  def create_issue(
        %{
          project: %{key: "PROJ"},
          issuetype: %{name: "Task"},
          summary: "New issue"
        },
        "token"
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
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
