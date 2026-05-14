defmodule Jido.Connect.Google.Sheets.Client do
  @moduledoc "Public Google Sheets client facade."

  alias Jido.Connect.Google.Sheets.Client

  defdelegate get_spreadsheet(params, access_token), to: Client.Spreadsheets
  defdelegate create_spreadsheet(params, access_token), to: Client.Spreadsheets
  defdelegate get_values(params, access_token), to: Client.Values
  defdelegate batch_get_values(params, access_token), to: Client.Values
  defdelegate update_values(params, access_token), to: Client.Values
  defdelegate append_values(params, access_token), to: Client.Values
  defdelegate clear_values(params, access_token), to: Client.Values
  defdelegate batch_update_values(params, access_token), to: Client.Values
  defdelegate batch_clear_values(params, access_token), to: Client.Values
  defdelegate add_sheet(params, access_token), to: Client.Spreadsheets
  defdelegate delete_sheet(params, access_token), to: Client.Spreadsheets
  defdelegate rename_sheet(params, access_token), to: Client.Spreadsheets
  defdelegate batch_update(params, access_token), to: Client.Spreadsheets
end
