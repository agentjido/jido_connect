defmodule Jido.Connect.Google.Tasks.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Tasks tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.tasks.tasklist.list",
    "google.tasks.tasklist.get",
    "google.tasks.task.list",
    "google.tasks.task.get",
    "google.tasks.task.changed"
  ]

  @editor_tools @readonly_tools ++
                  [
                    "google.tasks.tasklist.create",
                    "google.tasks.tasklist.update",
                    "google.tasks.tasklist.delete",
                    "google.tasks.task.create",
                    "google.tasks.task.update",
                    "google.tasks.task.delete",
                    "google.tasks.task.clear",
                    "google.tasks.task.move"
                  ]

  @doc "Returns all built-in Google Tasks catalog packs."
  def all, do: [readonly(), editor()]

  @doc "Read-only Tasks metadata and content pack."
  def readonly do
    Pack.new!(%{
      id: :google_tasks_readonly,
      label: "Google Tasks read-only",
      description:
        "Read Google Tasks task list and task data, and poll task changes, without mutation tools.",
      filters: %{provider: :google_tasks},
      allowed_tools: @readonly_tools,
      metadata: %{package: :jido_connect_google_tasks, risk: :read}
    })
  end

  @doc "Tasks editor pack for task list and task creation, update, and deletion."
  def editor do
    Pack.new!(%{
      id: :google_tasks_editor,
      label: "Google Tasks editor",
      description:
        "Read, create, update, and delete Google Tasks task lists and tasks. Includes all mutation tools.",
      filters: %{provider: :google_tasks},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_google_tasks, risk: :write}
    })
  end
end
