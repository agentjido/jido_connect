defmodule Jido.Connect.Jira.Previews.CreateFilter do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  alias Jido.Connect.Jira.Previews.Support

  def preview(input, _context) do
    %{
      operation: "create_filter",
      name: Map.get(input, :name),
      query_bytes: Support.byte_count(Map.get(input, :query)),
      description_bytes: Support.byte_count(Map.get(input, :description)),
      favorite: Map.get(input, :favorite, false)
    }
  end
end

defmodule Jido.Connect.Jira.Previews.UpdateFilter do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  alias Jido.Connect.Jira.Previews.Support

  def preview(input, _context) do
    %{
      operation: "update_filter",
      id: Map.get(input, :id),
      name: Map.get(input, :name),
      query_bytes: Support.byte_count(Map.get(input, :query)),
      description_bytes: Support.byte_count(Map.get(input, :description)),
      favorite: Map.get(input, :favorite)
    }
  end
end

defmodule Jido.Connect.Jira.Previews.UpdateFilterColumns do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  alias Jido.Connect.Jira.Previews.Support

  def preview(input, _context) do
    %{
      operation: "update_filter_columns",
      id: Map.get(input, :id),
      columns: Map.get(input, :columns, []),
      column_count: Support.item_count(Map.get(input, :columns))
    }
  end
end

defmodule Jido.Connect.Jira.Previews.UpdateFilterShare do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  alias Jido.Connect.Jira.Previews.Support

  def preview(input, _context) do
    %{
      operation: "replace_filter_shares",
      id: Map.get(input, :id),
      scope: Map.get(input, :scope),
      project_count: Support.item_count(Map.get(input, :projects)),
      group_count: Support.item_count(Map.get(input, :group_ids))
    }
  end
end
