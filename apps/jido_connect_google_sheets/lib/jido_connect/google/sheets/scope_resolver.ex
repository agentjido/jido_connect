defmodule Jido.Connect.Google.Sheets.ScopeResolver do
  @moduledoc """
  Resolves Google Sheets scopes.

  Google's full Sheets scope can satisfy read operations as well as write
  operations. The resolver preserves least-privilege read-only checks while
  allowing hosts that already granted full Sheets access to use read tools.
  """

  @read_scope "https://www.googleapis.com/auth/spreadsheets.readonly"
  @write_scope "https://www.googleapis.com/auth/spreadsheets"
  @write_actions [
    "google.sheets.spreadsheet.create",
    "google.sheets.values.update",
    "google.sheets.values.append",
    "google.sheets.values.clear",
    "google.sheets.values.batch_update",
    "google.sheets.values.batch_clear",
    "google.sheets.sheet.add",
    "google.sheets.sheet.delete",
    "google.sheets.sheet.rename",
    "google.sheets.batch_update"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, _connection) when operation_id in @write_actions,
    do: [@write_scope]

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    if @write_scope in scopes, do: [@write_scope], else: [@read_scope]
  end

  defp required_for_operation(_operation_id, _connection), do: [@read_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
