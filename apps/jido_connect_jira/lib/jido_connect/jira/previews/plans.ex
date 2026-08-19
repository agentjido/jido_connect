defmodule Jido.Connect.Jira.Previews.CreatePlan do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  alias Jido.Connect.Jira.Previews.Support

  def preview(input, _context) do
    %{
      operation: "create_plan",
      name: Map.get(input, :name),
      issue_source_count: Support.item_count(Map.get(input, :issue_sources)),
      release_count: Support.item_count(Map.get(input, :cross_project_releases)),
      custom_field_count: Support.item_count(Map.get(input, :custom_fields)),
      permission_count: Support.item_count(Map.get(input, :permissions))
    }
  end
end

defmodule Jido.Connect.Jira.Previews.UpdatePlan do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  alias Jido.Connect.Jira.Previews.Support

  def preview(input, _context) do
    %{
      operation: "update_plan",
      id: Map.get(input, :id),
      name: Map.get(input, :name),
      changed_fields: Support.changed_fields(input, [:id])
    }
  end
end

defmodule Jido.Connect.Jira.Previews.DuplicatePlan do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context),
    do: %{operation: "duplicate_plan", id: Map.get(input, :id), name: Map.get(input, :name)}
end

defmodule Jido.Connect.Jira.Previews.ArchivePlan do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context), do: %{operation: "archive_plan", id: Map.get(input, :id)}
end

defmodule Jido.Connect.Jira.Previews.TrashPlan do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context), do: %{operation: "trash_plan", id: Map.get(input, :id)}
end
