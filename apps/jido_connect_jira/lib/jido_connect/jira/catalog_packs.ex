defmodule Jido.Connect.Jira.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Jira tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:jira_reader` | read | issue and project queries |
  | `:jira_editor` | write | reader + issue mutations and comments |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @issue_read_tools [
    "jira.issue.get",
    "jira.issue.search"
  ]

  @project_read_tools [
    "jira.project.list",
    "jira.project.get"
  ]

  @metadata_read_tools [
    "jira.field_schema.list"
  ]

  @reader_tools @issue_read_tools ++
                  @project_read_tools ++
                  @metadata_read_tools

  @issue_write_tools [
    "jira.issue.create",
    "jira.issue.update",
    "jira.issue.transition",
    "jira.issue.assign",
    "jira.issue.comment.create"
  ]

  @editor_tools @reader_tools ++ @issue_write_tools

  @doc "Returns all built-in Jira catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Jira pack for issue, project, and field schema queries."
  def reader do
    Pack.new!(%{
      id: :jira_reader,
      label: "Jira reader",
      description: "Read Jira issues, projects, and field schemas without mutation tools.",
      filters: %{provider: :jira},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_jira, risk: :read}
    })
  end

  @doc "Jira editor pack for read, issue mutations, transitions, assignments, and comments."
  def editor do
    Pack.new!(%{
      id: :jira_editor,
      label: "Jira editor",
      description:
        "Read Jira issues, projects, and field schemas, plus create and update issues, transition, assign, and add comments.",
      filters: %{provider: :jira},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_jira, risk: :write}
    })
  end
end
