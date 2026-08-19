defmodule Jido.Connect.Jira.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Jira tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:jira_reader` | read | ordinary issue, project, board, and filter queries |
  | `:jira_editor` | write | reader + non-destructive issue, board, and filter writes |
  | `:jira_admin` | privileged | plan reads and non-destructive plan writes |
  | `:jira_destructive` | destructive | issue delete, plan archive, and plan trash |

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

  @board_read_tools [
    "jira.board.list",
    "jira.board.get"
  ]

  @filter_read_tools [
    "jira.filter.list",
    "jira.filter.get",
    "jira.filter.columns.get"
  ]

  @workflow_read_tools [
    "jira.issue.transition.list"
  ]

  @reader_tools @issue_read_tools ++
                  @project_read_tools ++
                  @metadata_read_tools ++
                  @board_read_tools ++
                  @filter_read_tools ++
                  @workflow_read_tools

  @issue_write_tools [
    "jira.issue.create",
    "jira.issue.update",
    "jira.issue.transition",
    "jira.issue.assign",
    "jira.issue.comment.create"
  ]

  @board_write_tools [
    "jira.board.create"
  ]

  @filter_write_tools [
    "jira.filter.create",
    "jira.filter.update",
    "jira.filter.columns.update",
    "jira.filter.share.update"
  ]

  @editor_tools @reader_tools ++ @issue_write_tools ++ @board_write_tools ++ @filter_write_tools

  @admin_tools [
    "jira.plan.list",
    "jira.plan.get",
    "jira.plan.create",
    "jira.plan.update",
    "jira.plan.duplicate"
  ]

  @destructive_tools [
    "jira.issue.delete",
    "jira.plan.archive",
    "jira.plan.trash"
  ]

  @doc "Returns all built-in Jira catalog packs."
  def all, do: [reader(), editor(), admin(), destructive()]

  @doc "Read-only Jira pack for ordinary Jira queries."
  def reader do
    Pack.new!(%{
      id: :jira_reader,
      label: "Jira reader",
      description:
        "Read Jira issues, projects, boards, filters, transitions, and field schemas without mutation tools.",
      filters: %{provider: :jira},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_jira, risk: :read}
    })
  end

  @doc "Jira editor pack for ordinary reads and non-destructive writes."
  def editor do
    Pack.new!(%{
      id: :jira_editor,
      label: "Jira editor",
      description: "Read Jira data and make non-destructive issue, board, and filter changes.",
      filters: %{provider: :jira},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_jira, risk: :write}
    })
  end

  @doc "Privileged Jira pack for non-destructive plan administration."
  def admin do
    Pack.new!(%{
      id: :jira_admin,
      label: "Jira plan administrator",
      description: "Read, create, update, and duplicate Jira plans with host policy approval.",
      filters: %{provider: :jira},
      allowed_tools: @admin_tools,
      metadata: %{package: :jido_connect_jira, risk: :privileged}
    })
  end

  @doc "Destructive Jira pack that must be selected explicitly."
  def destructive do
    Pack.new!(%{
      id: :jira_destructive,
      label: "Jira destructive operations",
      description: "Delete Jira issues, archive plans, or move plans to trash.",
      filters: %{provider: :jira},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_jira, risk: :destructive}
    })
  end
end
