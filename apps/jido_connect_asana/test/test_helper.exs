ExUnit.start()

defmodule Jido.Connect.Asana.MockClient do
  @moduledoc false

  alias Jido.Connect.Error

  # ---------------------------------------------------------------------------
  # Workspaces
  # ---------------------------------------------------------------------------

  def list_workspaces("token", opts) do
    per_page = Keyword.get(opts, :limit)

    workspaces =
      if per_page == 1 do
        [workspace_payload("112233", "Acme Corp")]
      else
        [
          workspace_payload("112233", "Acme Corp"),
          workspace_payload("224466", "Beta LLC")
        ]
      end

    pagination =
      if per_page == 1 do
        %{offset: "eyJvZmZzZXQiOiAiMQ", has_next: true}
      else
        %{offset: nil, has_next: false}
      end

    {:ok, %{items: workspaces, pagination: pagination}}
  end

  def list_workspaces("error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{
         message: "Not Authorized",
         body: %{"errors" => [%{"message" => "Not Authorized"}]}
       }
     }}
  end

  # ---------------------------------------------------------------------------
  # Projects
  # ---------------------------------------------------------------------------

  def list_projects("token", opts) do
    workspace = Keyword.get(opts, :workspace)

    projects =
      case workspace do
        "112233" ->
          [project_payload("445566", "Website Redesign")]

        _ ->
          [
            project_payload("445566", "Website Redesign"),
            project_payload("556677", "Mobile App")
          ]
      end

    {:ok, %{items: projects, pagination: %{offset: nil, has_next: false}}}
  end

  def list_projects("error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Tasks
  # ---------------------------------------------------------------------------

  def list_tasks("token", opts) do
    project = Keyword.get(opts, :project)

    tasks =
      case project do
        "445566" ->
          [task_payload("998877", "Design new landing page")]

        _ ->
          [
            task_payload("998877", "Design new landing page"),
            task_payload("998878", "Implement checkout flow")
          ]
      end

    {:ok, %{items: tasks, pagination: %{offset: nil, has_next: false}}}
  end

  def list_tasks("error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def get_task("998877", "token", _opts) do
    {:ok,
     %{
       gid: "998877",
       name: "Design new landing page",
       resource_type: "task",
       completed: false,
       due_on: "2026-07-15",
       notes: "Create wireframes and visual designs for the new landing page",
       assignee_gid: "123456",
       assignee_name: "Alice Nakamura",
       workspace_gid: "112233",
       project_gids: ["445566"]
     }}
  end

  def get_task("unknown", "token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :not_found,
       status: 404,
       details: %{message: "task: Not an object", body: %{}}
     }}
  end

  def get_task(_gid, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def search_tasks("112233", "token", opts) do
    query = Keyword.get(opts, :query)

    tasks =
      case query do
        "landing page" ->
          [task_payload("998877", "Design new landing page")]

        _ ->
          [
            task_payload("998877", "Design new landing page"),
            task_payload("998878", "Implement checkout flow")
          ]
      end

    {:ok, %{items: tasks, pagination: %{offset: nil, has_next: false}}}
  end

  def search_tasks(_workspace, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def create_task("token", task_params) do
    gid = "998899"
    name = Map.get(task_params, "name", "Untitled task")

    {:ok,
     %{
       gid: gid,
       name: name,
       resource_type: "task",
       completed: false,
       notes: Map.get(task_params, "notes"),
       assignee_gid: Map.get(task_params, "assignee"),
       workspace_gid: Map.get(task_params, "workspace"),
       project_gids: Map.get(task_params, "projects", []),
       tag_gids: Map.get(task_params, "tags", []),
       parent_gid: Map.get(task_params, "parent")
     }}
  end

  def create_task("error_token", _task_params) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def update_task("998877", "token", task_params) do
    {:ok,
     %{
       gid: "998877",
       name: Map.get(task_params, "name", "Design new landing page"),
       resource_type: "task",
       completed: Map.get(task_params, "completed", false),
       notes: Map.get(task_params, "notes", "Create wireframes"),
       assignee_gid: Map.get(task_params, "assignee", "123456"),
       workspace_gid: "112233",
       project_gids: ["445566"]
     }}
  end

  def update_task("unknown", "token", _task_params) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :not_found,
       status: 404,
       details: %{message: "task: Not an object", body: %{}}
     }}
  end

  def update_task(_gid, "error_token", _task_params) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def add_task_project("998877", "token", _project_gid) do
    {:ok, %{}}
  end

  def add_task_project(_task_gid, "error_token", _project_gid) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def remove_task_project("998877", "token", _project_gid) do
    {:ok, %{}}
  end

  def remove_task_project(_task_gid, "error_token", _project_gid) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def add_task_tag("998877", "token", _tag_gid) do
    {:ok, %{}}
  end

  def add_task_tag(_task_gid, "error_token", _tag_gid) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def remove_task_tag("998877", "token", _tag_gid) do
    {:ok, %{}}
  end

  def remove_task_tag(_task_gid, "error_token", _tag_gid) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Stories
  # ---------------------------------------------------------------------------

  def list_stories("998877", "token", _opts) do
    {:ok,
     %{
       items: [
         story_payload("334455", "comment_added", "Updated the wireframes based on feedback."),
         story_payload("334456", "assigned", nil)
       ],
       pagination: %{offset: nil, has_next: false}
     }}
  end

  def list_stories("empty_task", "token", _opts) do
    {:ok, %{items: [], pagination: %{offset: nil, has_next: false}}}
  end

  def list_stories(_task_gid, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def create_story("998877", "token", story_params) do
    text = Map.get(story_params, "text", "")

    {:ok,
     %{
       gid: "334456",
       resource_type: "story",
       resource_subtype: "comment_added",
       text: text,
       created_by: %{gid: "123456", name: "Alice Nakamura", resource_type: "user"},
       task_gid: "998877",
       target_gid: "998877"
     }}
  end

  def create_story(_task_gid, "error_token", _story_params) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------

  def get_user("123456", "token", _opts) do
    {:ok,
     %{
       gid: "123456",
       name: "Alice Nakamura",
       resource_type: "user",
       email: "alice@example.com"
     }}
  end

  def get_user("unknown", "token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :not_found,
       status: 404,
       details: %{message: "user: Not an object", body: %{}}
     }}
  end

  def get_user(_gid, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  def list_users("token", opts) do
    workspace = Keyword.get(opts, :workspace)

    users =
      case workspace do
        "112233" ->
          [user_payload("123456", "Alice Nakamura", "alice@example.com")]

        _ ->
          [
            user_payload("123456", "Alice Nakamura", "alice@example.com"),
            user_payload("123457", "Bob Martinez", "bob@example.com")
          ]
      end

    {:ok, %{items: users, pagination: %{offset: nil, has_next: false}}}
  end

  def list_users("error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Asana API request failed",
       provider: :asana,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Not Authorized", body: %{}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Client resolution helpers
  # ---------------------------------------------------------------------------

  def credential_token(%{api_key: key}), do: key
  def credential_token(%{access_token: token}), do: token

  # ---------------------------------------------------------------------------
  # Payload helpers
  # ---------------------------------------------------------------------------

  defp workspace_payload(gid, name) do
    %{gid: gid, name: name, resource_type: "workspace", is_organization: true}
  end

  defp project_payload(gid, name) do
    %{gid: gid, name: name, resource_type: "project", archived: false, public: true}
  end

  defp task_payload(gid, name) do
    %{gid: gid, name: name, resource_type: "task", completed: false}
  end

  defp story_payload(gid, subtype, text) do
    %{
      gid: gid,
      resource_type: "story",
      resource_subtype: subtype,
      text: text,
      created_by: %{gid: "123456", name: "Alice Nakamura", resource_type: "user"}
    }
  end

  defp user_payload(gid, name, email) do
    %{gid: gid, name: name, resource_type: "user", email: email}
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
