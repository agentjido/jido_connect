defmodule Jido.Connect.Linear.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Linear tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:linear_reader` | read | issue and team queries |
  | `:linear_editor` | write | reader + issue mutations and comments |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @issue_read_tools [
    "linear.issue.get",
    "linear.issue.search"
  ]

  @team_read_tools [
    "linear.team.list"
  ]

  @reader_tools @issue_read_tools ++ @team_read_tools

  @issue_write_tools [
    "linear.issue.create",
    "linear.issue.update",
    "linear.issue.comment.create"
  ]

  @editor_tools @reader_tools ++ @issue_write_tools

  @doc "Returns all built-in Linear catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Linear pack for issue and team queries."
  def reader do
    Pack.new!(%{
      id: :linear_reader,
      label: "Linear reader",
      description: "Read Linear issues and teams without mutation tools.",
      filters: %{provider: :linear},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_linear, risk: :read}
    })
  end

  @doc "Linear editor pack for read, issue mutations, and comments."
  def editor do
    Pack.new!(%{
      id: :linear_editor,
      label: "Linear editor",
      description:
        "Read Linear issues and teams, plus create and update issues, and add comments.",
      filters: %{provider: :linear},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_linear, risk: :write}
    })
  end
end
