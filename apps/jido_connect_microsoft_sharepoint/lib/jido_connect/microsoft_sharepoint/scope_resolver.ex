defmodule Jido.Connect.MicrosoftSharepoint.ScopeResolver do
  @moduledoc "Resolves SharePoint Graph scopes with selected-resource support."

  @sites_read "Sites.Read.All"
  @sites_write "Sites.ReadWrite.All"
  @sites_selected "Sites.Selected"
  @lists_selected "Lists.SelectedOperations.Selected"
  @list_items_selected "ListItems.SelectedOperations.Selected"
  @files_read "Files.Read.All"
  @files_write "Files.ReadWrite.All"
  @files_selected "Files.SelectedOperations.Selected"

  @write_actions [
    "microsoft.sharepoint.list.item.create",
    "microsoft.sharepoint.list.item.update",
    "microsoft.sharepoint.list.item.delete"
  ]

  @search_actions ["microsoft.sharepoint.sites.search"]
  @list_actions [
    "microsoft.sharepoint.list.get",
    "microsoft.sharepoint.list.columns.list",
    "microsoft.sharepoint.list.items.list"
  ]
  @item_actions ["microsoft.sharepoint.list.item.get"]

  @library_site_actions ["microsoft.sharepoint.libraries.list"]
  @library_read_actions [
    "microsoft.sharepoint.library.items.list",
    "microsoft.sharepoint.library.item.get",
    "microsoft.sharepoint.library.items.search",
    "microsoft.sharepoint.library.item.download",
    "microsoft.sharepoint.library.items.delta"
  ]
  @library_write_actions [
    "microsoft.sharepoint.library.folder.create",
    "microsoft.sharepoint.library.item.upload",
    "microsoft.sharepoint.library.item.update",
    "microsoft.sharepoint.library.item.delete"
  ]

  @spec required_scopes(map(), map(), map()) :: [String.t()]
  def required_scopes(operation, _input, connection) do
    operation_id = operation_id(operation)
    scopes = Map.get(connection, :scopes, [])

    cond do
      operation_id in @library_write_actions -> library_write_scope(scopes)
      operation_id in @library_read_actions -> library_read_scope(scopes)
      operation_id in @library_site_actions -> library_site_scope(scopes)
      operation_id in @write_actions -> write_scope(operation_id, scopes)
      operation_id in @search_actions -> tenant_read_scope(scopes)
      operation_id in @item_actions -> item_read_scope(scopes)
      operation_id in @list_actions -> list_read_scope(scopes)
      true -> site_read_scope(scopes)
    end
  end

  defp write_scope(operation_id, scopes) do
    cond do
      operation_id != "microsoft.sharepoint.list.item.create" and
          @list_items_selected in scopes ->
        [@list_items_selected]

      @lists_selected in scopes ->
        [@lists_selected]

      @sites_selected in scopes ->
        [@sites_selected]

      @sites_write in scopes ->
        [@sites_write]

      true ->
        [@sites_write]
    end
  end

  defp tenant_read_scope(scopes) do
    cond do
      @sites_read in scopes -> [@sites_read]
      @sites_write in scopes -> [@sites_write]
      true -> [@sites_read]
    end
  end

  defp library_site_scope(scopes) do
    cond do
      @sites_selected in scopes -> [@sites_selected]
      @files_read in scopes -> [@files_read]
      @files_write in scopes -> [@files_write]
      true -> tenant_read_scope(scopes)
    end
  end

  defp library_read_scope(scopes) do
    cond do
      @files_selected in scopes -> [@files_selected]
      @sites_selected in scopes -> [@sites_selected]
      @files_read in scopes -> [@files_read]
      @files_write in scopes -> [@files_write]
      @sites_read in scopes -> [@sites_read]
      @sites_write in scopes -> [@sites_write]
      true -> [@files_read]
    end
  end

  defp library_write_scope(scopes) do
    cond do
      @files_selected in scopes -> [@files_selected]
      @sites_selected in scopes -> [@sites_selected]
      @files_write in scopes -> [@files_write]
      @sites_write in scopes -> [@sites_write]
      true -> [@files_write]
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
