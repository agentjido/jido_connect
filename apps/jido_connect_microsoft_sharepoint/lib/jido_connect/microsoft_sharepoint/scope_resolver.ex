defmodule Jido.Connect.MicrosoftSharepoint.ScopeResolver do
  @moduledoc "Resolves SharePoint Graph scopes with selected-resource support."

  @sites_read "Sites.Read.All"
  @sites_write "Sites.ReadWrite.All"
  @sites_selected "Sites.Selected"
  @lists_selected "Lists.SelectedOperations.Selected"
  @list_items_selected "ListItems.SelectedOperations.Selected"

  @search_actions ["microsoft.sharepoint.sites.search"]
  @list_actions [
    "microsoft.sharepoint.list.get",
    "microsoft.sharepoint.list.columns.list",
    "microsoft.sharepoint.list.items.list"
  ]
  @item_actions ["microsoft.sharepoint.list.item.get"]

  @spec required_scopes(map(), map(), map()) :: [String.t()]
  def required_scopes(operation, _input, connection) do
    operation_id = operation_id(operation)
    scopes = Map.get(connection, :scopes, [])

    cond do
      operation_id in @search_actions -> tenant_read_scope(scopes)
      operation_id in @item_actions -> item_read_scope(scopes)
      operation_id in @list_actions -> list_read_scope(scopes)
      true -> site_read_scope(scopes)
    end
  end

  defp tenant_read_scope(scopes) do
    cond do
      @sites_read in scopes -> [@sites_read]
      @sites_write in scopes -> [@sites_write]
      true -> [@sites_read]
    end
  end

  defp site_read_scope(scopes) do
    cond do
      @sites_selected in scopes -> [@sites_selected]
      true -> tenant_read_scope(scopes)
    end
  end

  defp list_read_scope(scopes) do
    cond do
      @lists_selected in scopes -> [@lists_selected]
      true -> site_read_scope(scopes)
    end
  end

  defp item_read_scope(scopes) do
    cond do
      @list_items_selected in scopes -> [@list_items_selected]
      true -> list_read_scope(scopes)
    end
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: id}), do: id
  defp operation_id(_operation), do: nil
end
