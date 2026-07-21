defmodule Jido.Connect.Asana.Normalizer do
  @moduledoc "Normalizes Asana API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Asana.{
    CustomField,
    Pagination,
    Project,
    Section,
    Story,
    Tag,
    Task,
    User,
    Workspace
  }

  # ---------------------------------------------------------------------------
  # Workspace
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana workspace payload."
  @spec workspace(map()) :: {:ok, Workspace.t()} | {:error, term()}
  def workspace(payload) when is_map(payload) do
    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      is_organization: Data.get(payload, "is_organization"),
      email_domains: Data.get(payload, "email_domains")
    }
    |> Data.compact()
    |> Workspace.new()
  end

  def workspace(_payload), do: {:error, :invalid_workspace_payload}

  # ---------------------------------------------------------------------------
  # Project
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana project payload."
  @spec project(map()) :: {:ok, Project.t()} | {:error, term()}
  def project(payload) when is_map(payload) do
    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      color: Data.get(payload, "color"),
      archived: Data.get(payload, "archived"),
      public: Data.get(payload, "public"),
      due_date: Data.get(payload, "due_date"),
      due_on: Data.get(payload, "due_on"),
      start_on: Data.get(payload, "start_on"),
      notes: Data.get(payload, "notes"),
      html_notes: Data.get(payload, "html_notes"),
      current_status: Data.get(payload, "current_status"),
      default_view: Data.get(payload, "default_view"),
      workspace_gid: extract_gid(Data.get(payload, "workspace")),
      team_gid: extract_gid(Data.get(payload, "team")),
      owner_gid: extract_gid(Data.get(payload, "owner")),
      created_at: Data.get(payload, "created_at"),
      modified_at: Data.get(payload, "modified_at")
    }
    |> Data.compact()
    |> Project.new()
  end

  def project(_payload), do: {:error, :invalid_project_payload}

  # ---------------------------------------------------------------------------
  # Task
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana task payload."
  @spec task(map()) :: {:ok, Task.t()} | {:error, term()}
  def task(payload) when is_map(payload) do
    assignee = Data.get(payload, "assignee", %{})

    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      assignee_gid: extract_gid(assignee),
      assignee_name: Data.get(assignee, "name"),
      assignee_status: Data.get(payload, "assignee_status"),
      completed: Data.get(payload, "completed"),
      completed_at: Data.get(payload, "completed_at"),
      due_on: Data.get(payload, "due_on"),
      due_at: Data.get(payload, "due_at"),
      start_on: Data.get(payload, "start_on"),
      start_at: Data.get(payload, "start_at"),
      notes: Data.get(payload, "notes"),
      html_notes: Data.get(payload, "html_notes"),
      num_hearts: Data.get(payload, "num_hearts"),
      num_likes: Data.get(payload, "num_likes"),
      parent_gid: extract_gid(Data.get(payload, "parent")),
      workspace_gid: extract_gid(Data.get(payload, "workspace")),
      project_gids: extract_gids(Data.get(payload, "projects")),
      tag_gids: extract_gids(Data.get(payload, "tags")),
      section_gid: extract_gid(Data.get(payload, "memberships", []) |> extract_section()),
      custom_fields: extract_custom_fields(Data.get(payload, "custom_fields")),
      created_at: Data.get(payload, "created_at"),
      modified_at: Data.get(payload, "modified_at")
    }
    |> Data.compact()
    |> Task.new()
  end

  def task(_payload), do: {:error, :invalid_task_payload}

  # ---------------------------------------------------------------------------
  # Section
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana section payload."
  @spec section(map()) :: {:ok, Section.t()} | {:error, term()}
  def section(payload) when is_map(payload) do
    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      project_gid: extract_gid(Data.get(payload, "project")),
      created_at: Data.get(payload, "created_at"),
      modified_at: Data.get(payload, "modified_at")
    }
    |> Data.compact()
    |> Section.new()
  end

  def section(_payload), do: {:error, :invalid_section_payload}

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana user payload."
  @spec user(map()) :: {:ok, User.t()} | {:error, term()}
  def user(payload) when is_map(payload) do
    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      email: Data.get(payload, "email"),
      photo: Data.get(payload, "photo"),
      workspaces: Data.get(payload, "workspaces")
    }
    |> Data.compact()
    |> User.new()
  end

  def user(_payload), do: {:error, :invalid_user_payload}

  # ---------------------------------------------------------------------------
  # Story
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana story (comment/activity) payload."
  @spec story(map()) :: {:ok, Story.t()} | {:error, term()}
  def story(payload) when is_map(payload) do
    created_by = Data.get(payload, "created_by", %{})
    target = Data.get(payload, "target", %{})

    %{
      gid: Data.get(payload, "gid"),
      resource_type: Data.get(payload, "resource_type"),
      resource_subtype: Data.get(payload, "resource_subtype"),
      text: Data.get(payload, "text"),
      html_text: Data.get(payload, "html_text"),
      is_pinned: Data.get(payload, "is_pinned"),
      sticker_name: Data.get(payload, "sticker_name"),
      num_likes: Data.get(payload, "num_likes"),
      liked: Data.get(payload, "liked"),
      created_by: created_by,
      target_gid: extract_gid(target),
      target_resource_type: Data.get(target, "resource_type"),
      task_gid: extract_gid(Data.get(payload, "task")),
      project_gid: extract_gid(Data.get(payload, "project")),
      created_at: Data.get(payload, "created_at")
    }
    |> Data.compact()
    |> Story.new()
  end

  def story(_payload), do: {:error, :invalid_story_payload}

  # ---------------------------------------------------------------------------
  # Tag
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana tag payload."
  @spec tag(map()) :: {:ok, Tag.t()} | {:error, term()}
  def tag(payload) when is_map(payload) do
    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      color: Data.get(payload, "color"),
      notes: Data.get(payload, "notes"),
      workspace_gid: extract_gid(Data.get(payload, "workspace")),
      created_at: Data.get(payload, "created_at")
    }
    |> Data.compact()
    |> Tag.new()
  end

  def tag(_payload), do: {:error, :invalid_tag_payload}

  # ---------------------------------------------------------------------------
  # CustomField
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana custom field definition payload."
  @spec custom_field(map()) :: {:ok, CustomField.t()} | {:error, term()}
  def custom_field(payload) when is_map(payload) do
    %{
      gid: Data.get(payload, "gid"),
      name: Data.get(payload, "name"),
      resource_type: Data.get(payload, "resource_type"),
      resource_subtype: Data.get(payload, "resource_subtype"),
      type: Data.get(payload, "type"),
      description: Data.get(payload, "description"),
      enabled: Data.get(payload, "enabled"),
      precision: Data.get(payload, "precision"),
      enum_options: Data.get(payload, "enum_options"),
      enum_value: Data.get(payload, "enum_value"),
      number_value: Data.get(payload, "number_value"),
      text_value: Data.get(payload, "text_value"),
      multi_enum_values: Data.get(payload, "multi_enum_values"),
      workspace_gid: extract_gid(Data.get(payload, "workspace")),
      created_at: Data.get(payload, "created_at")
    }
    |> Data.compact()
    |> CustomField.new()
  end

  def custom_field(_payload), do: {:error, :invalid_custom_field_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Asana API `next_page` envelope."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    next_page = Data.get(payload, "next_page", %{}) || %{}

    %{
      offset: Data.get(next_page, "offset"),
      path: Data.get(next_page, "path"),
      uri: Data.get(next_page, "uri"),
      has_next: Data.get(next_page, "offset") != nil
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp extract_gid(nil), do: nil
  defp extract_gid(%{"gid" => gid}), do: gid
  defp extract_gid(%{gid: gid}), do: to_string(gid)
  defp extract_gid(_), do: nil

  defp extract_gids(nil), do: []
  defp extract_gids(items) when is_list(items), do: Enum.map(items, &extract_gid/1)
  defp extract_gids(_), do: []

  defp extract_section([]), do: nil
  defp extract_section([%{"section" => section} | _]), do: section
  defp extract_section([_ | rest]), do: extract_section(rest)
  defp extract_section(_), do: nil

  defp extract_custom_fields(nil), do: nil

  defp extract_custom_fields(fields) when is_list(fields) do
    fields
    |> Enum.map(fn field ->
      gid = Data.get(field, "gid")
      name = Data.get(field, "name")

      value =
        cond do
          Data.get(field, "enum_value") != nil -> Data.get(field, "enum_value")
          Data.get(field, "number_value") != nil -> Data.get(field, "number_value")
          Data.get(field, "text_value") != nil -> Data.get(field, "text_value")
          Data.get(field, "multi_enum_values") != nil -> Data.get(field, "multi_enum_values")
          true -> nil
        end

      %{gid => %{name: name, value: value}}
    end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp extract_custom_fields(_), do: nil
end
