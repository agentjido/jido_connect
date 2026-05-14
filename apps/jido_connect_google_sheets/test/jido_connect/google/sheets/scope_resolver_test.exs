defmodule Jido.Connect.Google.Sheets.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Sheets.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @read_scope "https://www.googleapis.com/auth/spreadsheets.readonly"
  @write_scope "https://www.googleapis.com/auth/spreadsheets"

  test "declares Sheets read, broad, and mutation scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "missing product grant falls back to read-only scope",
        operation: "google.sheets.spreadsheet.get",
        granted: [],
        expected: @read_scope
      },
      %{
        label: "narrow read scope remains least-privilege",
        operation: "google.sheets.values.get",
        granted: [@read_scope],
        expected: @read_scope
      },
      %{
        label: "broad write grant can satisfy reads",
        operation: "google.sheets.values.get",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "values mutation requires full Sheets scope",
        operation: "google.sheets.values.update",
        granted: [@read_scope],
        expected: @write_scope
      },
      %{
        label: "values batch get can use read-only scope",
        operation: "google.sheets.values.batch_get",
        granted: [@read_scope],
        expected: @read_scope
      },
      %{
        label: "values batch mutation requires full Sheets scope",
        operation: "google.sheets.values.batch_update",
        granted: [@read_scope],
        expected: @write_scope
      },
      %{
        label: "data-filter read requires full Sheets scope per Google endpoint",
        operation: "google.sheets.values.batch_get_by_data_filter",
        granted: [@read_scope],
        expected: @write_scope
      },
      %{
        label: "developer metadata search requires full Sheets scope",
        operation: "google.sheets.developer_metadata.search",
        granted: [@read_scope],
        expected: @write_scope
      },
      %{
        label: "spreadsheet create requires full Sheets scope",
        operation: "google.sheets.spreadsheet.create",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "sheet management mutation requires full Sheets scope",
        operation: "google.sheets.sheet.delete",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "raw batch update requires full Sheets scope",
        operation: "google.sheets.batch_update",
        granted: [],
        expected: @write_scope
      }
    ])
  end
end
