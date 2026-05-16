ExUnit.start()

defmodule Jido.Connect.Linear.MockClient do
  @moduledoc false

  def get_issue("LIN-123", "token", _opts) do
    {:ok,
     %{
       id: "uuid-001",
       identifier: "LIN-123",
       title: "Test issue",
       description: "A test issue description",
       status: %{id: "status-1", name: "In Progress", type: "started", color: "#F2C94C"},
       priority: %{value: 3, label: "Medium"},
       priority_label: "Medium",
       team: %{id: "team-1", key: "LIN", name: "Linear Team"},
       assignee: %{id: "user-1", name: "Test User", email: "test@example.com"},
       labels: [%{id: "label-1", name: "bug", color: "#E5484D"}],
       created_at: "2026-05-15T10:00:00.000Z",
       updated_at: "2026-05-15T12:00:00.000Z"
     }}
  end

  def get_issue("LIN-123", "token") do
    get_issue("LIN-123", "token", [])
  end

  def search_issues(%{}, "token", _opts) do
    {:ok,
     %{
       issues: [
         %{
           id: "uuid-001",
           identifier: "LIN-123",
           title: "Test issue",
           status: %{id: "status-1", name: "In Progress", type: "started", color: "#F2C94C"},
           team: %{id: "team-1", key: "LIN", name: "Linear Team"},
           updated_at: "2026-05-15T12:00:00.000Z"
         }
       ],
       has_next_page: false,
       end_cursor: nil,
       total_count: 1
     }}
  end

  def create_issue(
        %{
          team_id: "team-1",
          title: "New issue"
        },
        "token"
      ) do
    {:ok,
     %{
       id: "uuid-002",
       identifier: "LIN-124",
       title: "New issue"
     }}
  end

  def create_issue(%{team_id: "team-1"}, "token") do
    {:ok,
     %{
       id: "uuid-002",
       identifier: "LIN-124",
       title: "Created issue"
     }}
  end

  def update_issue("LIN-ERR", _fields, "token") do
    {:error, Jido.Connect.Error.provider("Linear API error", reason: :graphql_error)}
  end

  def update_issue(_issue_id, _fields, "token") do
    {:ok, %{updated: true}}
  end

  def list_teams("token", _opts) do
    {:ok,
     %{
       teams: [
         %{id: "team-1", key: "LIN", name: "Linear Team", icon: "🚀", color: "#5B5DEF"},
         %{id: "team-2", key: "ENG", name: "Engineering", icon: "⚙️", color: "#F2C94C"}
       ],
       has_next_page: false,
       end_cursor: nil
     }}
  end

  def add_comment("LIN-ERR", _body_text, "token") do
    {:error, Jido.Connect.Error.provider("Linear API error", reason: :graphql_error)}
  end

  def add_comment(_issue_id, _body_text, "token") do
    {:ok,
     %{
       id: "comment-1",
       body: "Test comment body",
       created_at: "2026-05-15T14:00:00.000Z"
     }}
  end

  def list_comments("uuid-001", "token", _opts) do
    {:ok,
     %{
       comments: [
         %{
           id: "comment-1",
           body: "Investigated the OAuth2 flow.",
           author: %{id: "user-1", name: "Alice Nakamura", email: "alice@example.com"},
           parent_id: "uuid-001",
           created_at: "2026-05-01T10:30:00.000Z",
           updated_at: "2026-05-01T10:30:00.000Z"
         },
         %{
           id: "comment-2",
           body: "Implemented the authorization code flow.",
           author: %{id: "user-2", name: "Bob Martinez", email: "bob@example.com"},
           parent_id: "uuid-001",
           created_at: "2026-05-05T14:00:00.000Z",
           updated_at: "2026-05-05T14:00:00.000Z"
         }
       ],
       has_next_page: false,
       end_cursor: nil,
       total_count: 2
     }}
  end

  def get_team("team-1", "token", _opts) do
    {:ok,
     %{
       id: "team-1",
       key: "LIN",
       name: "Linear Team",
       description: "Core Linear product team.",
       icon: "🚀",
       color: "#5B5DEF",
       lead: %{id: "user-1", name: "Alice Nakamura", email: "alice@example.com"}
     }}
  end

  def get_team("team-1", "token") do
    get_team("team-1", "token", [])
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
