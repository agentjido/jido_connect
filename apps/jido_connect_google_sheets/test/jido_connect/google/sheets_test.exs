defmodule Jido.Connect.Google.SheetsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.Google.Sheets

  @sheets_action_modules [
    Jido.Connect.Google.Sheets.Actions.GetSpreadsheet,
    Jido.Connect.Google.Sheets.Actions.GetValues,
    Jido.Connect.Google.Sheets.Actions.BatchGetValues,
    Jido.Connect.Google.Sheets.Actions.UpdateValues,
    Jido.Connect.Google.Sheets.Actions.AppendValues,
    Jido.Connect.Google.Sheets.Actions.ClearValues,
    Jido.Connect.Google.Sheets.Actions.BatchUpdateValues,
    Jido.Connect.Google.Sheets.Actions.BatchClearValues,
    Jido.Connect.Google.Sheets.Actions.CreateSpreadsheet,
    Jido.Connect.Google.Sheets.Actions.AddSheet,
    Jido.Connect.Google.Sheets.Actions.DeleteSheet,
    Jido.Connect.Google.Sheets.Actions.RenameSheet,
    Jido.Connect.Google.Sheets.Actions.BatchUpdate,
    Jido.Connect.Google.Sheets.Actions.GetSpreadsheetByDataFilter,
    Jido.Connect.Google.Sheets.Actions.BatchGetValuesByDataFilter,
    Jido.Connect.Google.Sheets.Actions.BatchUpdateValuesByDataFilter,
    Jido.Connect.Google.Sheets.Actions.BatchClearValuesByDataFilter,
    Jido.Connect.Google.Sheets.Actions.GetDeveloperMetadata,
    Jido.Connect.Google.Sheets.Actions.SearchDeveloperMetadata
  ]

  @sheets_dsl_fragments [
    Jido.Connect.Google.Sheets.Actions.Read,
    Jido.Connect.Google.Sheets.Actions.Write,
    Jido.Connect.Google.Sheets.Actions.ManageSpreadsheets,
    Jido.Connect.Google.Sheets.Actions.ManageSheets,
    Jido.Connect.Google.Sheets.Actions.DataFilters,
    Jido.Connect.Google.Sheets.Actions.DeveloperMetadata
  ]

  defmodule FakeSheetsClient do
    def get_spreadsheet(
          %{spreadsheet_id: "sheet123", ranges: [], include_grid_data: false},
          "token"
        ) do
      {:ok,
       Sheets.Spreadsheet.new!(%{
         spreadsheet_id: "sheet123",
         title: "Budget",
         sheets: [
           %{
             sheet_id: 0,
             title: "Sheet1"
           }
         ]
       })}
    end

    def get_values(%{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2"}, "token") do
      {:ok,
       Sheets.ValueRange.new!(%{
         range: "Sheet1!A1:B2",
         values: [["Name", "Count"], ["A", 1]]
       })}
    end

    def batch_get_values(%{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"]}, "token") do
      {:ok,
       %{
         spreadsheet_id: "sheet123",
         value_ranges: [
           Sheets.ValueRange.new!(%{
             range: "Sheet1!A1:B2",
             values: [["Name", "Count"]]
           })
         ]
       }}
    end

    def get_spreadsheet_by_data_filter(
          %{
            spreadsheet_id: "sheet123",
            data_filters: [%{a1Range: "Sheet1!A1:B2"}],
            include_grid_data: false,
            exclude_tables_in_banded_ranges: false
          },
          "token"
        ) do
      {:ok,
       Sheets.Spreadsheet.new!(%{
         spreadsheet_id: "sheet123",
         title: "Budget",
         sheets: [%{sheet_id: 0, title: "Sheet1"}]
       })}
    end

    def batch_get_values_by_data_filter(
          %{spreadsheet_id: "sheet123", data_filters: [%{a1Range: "Sheet1!A1:B2"}]},
          "token"
        ) do
      {:ok,
       %{
         spreadsheet_id: "sheet123",
         value_ranges: [
           %{
             value_range:
               Sheets.ValueRange.new!(%{
                 range: "Sheet1!A1:B2",
                 values: [["Name", "Count"]]
               }),
             data_filters: [%{a1Range: "Sheet1!A1:B2"}]
           }
         ]
       }}
    end

    def create_spreadsheet(%{title: "Budget"}, "token") do
      {:ok,
       Sheets.Spreadsheet.new!(%{
         spreadsheet_id: "sheet123",
         title: "Budget",
         sheets: [%{sheet_id: 0, title: "Sheet1"}]
       })}
    end

    def update_values(
          %{
            spreadsheet_id: "sheet123",
            range: "Sheet1!A1:B2",
            values: [["Name", "Count"]],
            major_dimension: "ROWS",
            value_input_option: "RAW",
            include_values_in_response: false
          },
          "token"
        ) do
      {:ok,
       Sheets.UpdateResult.new!(%{
         spreadsheet_id: "sheet123",
         updated_range: "Sheet1!A1:B2",
         updated_rows: 1,
         updated_columns: 2,
         updated_cells: 2
       })}
    end

    def append_values(
          %{
            spreadsheet_id: "sheet123",
            range: "Sheet1!A1:B2",
            values: [["A", 1]],
            major_dimension: "ROWS",
            value_input_option: "RAW",
            include_values_in_response: false
          },
          "token"
        ) do
      {:ok,
       Sheets.UpdateResult.new!(%{
         spreadsheet_id: "sheet123",
         table_range: "Sheet1!A1:B2",
         updated_range: "Sheet1!A3:B3",
         updated_rows: 1,
         updated_columns: 2,
         updated_cells: 2
       })}
    end

    def clear_values(%{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2"}, "token") do
      {:ok,
       Sheets.UpdateResult.new!(%{
         spreadsheet_id: "sheet123",
         cleared_range: "Sheet1!A1:B2"
       })}
    end

    def batch_update_values(
          %{
            spreadsheet_id: "sheet123",
            value_input_option: "RAW",
            include_values_in_response: false,
            data: [
              %{
                range: "Sheet1!A1:B2",
                values: [["Name", "Count"]],
                major_dimension: "ROWS"
              }
            ]
          },
          "token"
        ) do
      {:ok,
       %{
         spreadsheet_id: "sheet123",
         total_updated_cells: 2,
         responses: [
           Sheets.UpdateResult.new!(%{
             updated_range: "Sheet1!A1:B2",
             updated_cells: 2
           })
         ]
       }}
    end

    def batch_update_values_by_data_filter(
          %{
            spreadsheet_id: "sheet123",
            value_input_option: "RAW",
            include_values_in_response: false,
            data: [
              %{
                data_filter: %{a1Range: "Sheet1!A1:B2"},
                values: [["Name", "Count"]]
              }
            ]
          },
          "token"
        ) do
      {:ok,
       %{
         spreadsheet_id: "sheet123",
         total_updated_cells: 2,
         responses: [
           %{
             updated_range: "Sheet1!A1:B2",
             updated_cells: 2,
             data_filter: %{a1Range: "Sheet1!A1:B2"}
           }
         ]
       }}
    end

    def batch_clear_values(%{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"]}, "token") do
      {:ok, %{spreadsheet_id: "sheet123", cleared_ranges: ["Sheet1!A1:B2"]}}
    end

    def batch_clear_values_by_data_filter(
          %{spreadsheet_id: "sheet123", data_filters: [%{a1Range: "Sheet1!A1:B2"}]},
          "token"
        ) do
      {:ok, %{spreadsheet_id: "sheet123", cleared_ranges: ["Sheet1!A1:B2"]}}
    end

    def add_sheet(%{spreadsheet_id: "sheet123", title: "Forecast"}, "token") do
      {:ok,
       Sheets.Sheet.new!(%{
         sheet_id: 123,
         title: "Forecast",
         index: 1
       })}
    end

    def delete_sheet(%{spreadsheet_id: "sheet123", sheet_id: 123}, "token") do
      {:ok, %{spreadsheet_id: "sheet123", sheet_id: 123}}
    end

    def rename_sheet(%{spreadsheet_id: "sheet123", sheet_id: 123, title: "Renamed"}, "token") do
      {:ok,
       Sheets.Sheet.new!(%{
         sheet_id: 123,
         title: "Renamed"
       })}
    end

    def batch_update(
          %{
            spreadsheet_id: "sheet123",
            requests: [%{repeatCell: %{fields: "userEnteredFormat.textFormat.bold"}}],
            include_spreadsheet_in_response: false,
            response_ranges: [],
            response_include_grid_data: false
          },
          "token"
        ) do
      {:ok, %{spreadsheet_id: "sheet123", replies: [%{}]}}
    end

    def get_developer_metadata(%{spreadsheet_id: "sheet123", metadata_id: 123}, "token") do
      {:ok,
       Sheets.DeveloperMetadata.new!(%{
         metadata_id: 123,
         metadata_key: "sync_id",
         metadata_value: "abc",
         visibility: "DOCUMENT"
       })}
    end

    def search_developer_metadata(
          %{
            spreadsheet_id: "sheet123",
            data_filters: [%{developerMetadataLookup: %{metadataKey: "sync_id"}}]
          },
          "token"
        ) do
      {:ok,
       %{
         matched_developer_metadata: [
           %{
             developer_metadata:
               Sheets.DeveloperMetadata.new!(%{
                 metadata_id: 123,
                 metadata_key: "sync_id",
                 metadata_value: "abc",
                 visibility: "DOCUMENT"
               }),
             data_filters: [%{developerMetadataLookup: %{metadataKey: "sync_id"}}]
           }
         ]
       }}
    end
  end

  test "declares Google Sheets provider metadata" do
    spec = Sheets.integration()

    assert spec.id == :google_sheets
    assert spec.package == :jido_connect_google_sheets
    assert spec.name == "Google Sheets"
    assert spec.tags == [:google, :workspace, :spreadsheets, :productivity]

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Sheets,
      id_prefix: "google.sheets.",
      pack_id_prefix: "google_sheets_",
      module_namespace: Jido.Connect.Google.Sheets
    )

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/spreadsheets.readonly" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "google.sheets.spreadsheet.get",
             "google.sheets.values.get",
             "google.sheets.values.batch_get",
             "google.sheets.values.update",
             "google.sheets.values.append",
             "google.sheets.values.clear",
             "google.sheets.values.batch_update",
             "google.sheets.values.batch_clear",
             "google.sheets.spreadsheet.create",
             "google.sheets.sheet.add",
             "google.sheets.sheet.delete",
             "google.sheets.sheet.rename",
             "google.sheets.batch_update",
             "google.sheets.spreadsheet.get_by_data_filter",
             "google.sheets.values.batch_get_by_data_filter",
             "google.sheets.values.batch_update_by_data_filter",
             "google.sheets.values.batch_clear_by_data_filter",
             "google.sheets.developer_metadata.get",
             "google.sheets.developer_metadata.search"
           ]
  end

  test "compiles generated Jido modules for actions and plugin" do
    ConnectorContracts.assert_generated_surface(Sheets,
      otp_app: :jido_connect_google_sheets,
      action_modules: @sheets_action_modules,
      plugin_module: Jido.Connect.Google.Sheets.Plugin,
      plugin_name: "google_sheets"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Sheets,
      readonly_pack: :google_sheets_readonly,
      writer_pack: :google_sheets_writer
    )
  end

  test "loads Sheets Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@sheets_dsl_fragments)
  end

  test "resolves Sheets scopes for read/write operation shapes" do
    resolver = Jido.Connect.Google.Sheets.ScopeResolver

    ConnectorContracts.assert_scope_resolver_shape(resolver, [
      "https://www.googleapis.com/auth/spreadsheets.readonly"
    ])

    assert resolver.required_scopes(
             %{id: "google.sheets.values.update"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"]}
           ) == ["https://www.googleapis.com/auth/spreadsheets"]

    assert resolver.required_scopes(
             %{id: "google.sheets.values.batch_update"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"]}
           ) == ["https://www.googleapis.com/auth/spreadsheets"]

    assert resolver.required_scopes(
             %{id: "google.sheets.values.batch_get_by_data_filter"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"]}
           ) == ["https://www.googleapis.com/auth/spreadsheets"]

    assert resolver.required_scopes(
             %{action_id: "google.sheets.values.get"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/spreadsheets"]}
           ) == ["https://www.googleapis.com/auth/spreadsheets"]

    assert resolver.required_scopes(%{}, %{}, %{}) == [
             "https://www.googleapis.com/auth/spreadsheets.readonly"
           ]
  end

  test "invokes get spreadsheet through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              spreadsheet: %{
                spreadsheet_id: "sheet123",
                title: "Budget",
                sheets: [%{sheet_id: 0, title: "Sheet1"}]
              }
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.spreadsheet.get",
               %{spreadsheet_id: "sheet123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get values through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              value_range: %{
                range: "Sheet1!A1:B2",
                values: [["Name", "Count"], ["A", 1]]
              }
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.get",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch get values through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              spreadsheet_id: "sheet123",
              value_ranges: [%{range: "Sheet1!A1:B2", values: [["Name", "Count"]]}]
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_get",
               %{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get spreadsheet by data filter through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{spreadsheet: %{spreadsheet_id: "sheet123", title: "Budget"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.spreadsheet.get_by_data_filter",
               %{spreadsheet_id: "sheet123", data_filters: [%{a1Range: "Sheet1!A1:B2"}]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch get by data filter through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              spreadsheet_id: "sheet123",
              value_ranges: [
                %{
                  value_range: %{range: "Sheet1!A1:B2", values: [["Name", "Count"]]},
                  data_filters: [%{a1Range: "Sheet1!A1:B2"}]
                }
              ]
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_get_by_data_filter",
               %{spreadsheet_id: "sheet123", data_filters: [%{a1Range: "Sheet1!A1:B2"}]},
               context: context,
               credential_lease: lease
             )
  end

  test "read actions accept full Sheets write scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/spreadsheets"
        ]
      )

    assert {:ok, %{value_range: %{range: "Sheet1!A1:B2"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.get",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update values through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              update: %{
                spreadsheet_id: "sheet123",
                updated_range: "Sheet1!A1:B2",
                updated_cells: 2
              }
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.update",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2", values: [["Name", "Count"]]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create spreadsheet through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{spreadsheet: %{spreadsheet_id: "sheet123", title: "Budget"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.spreadsheet.create",
               %{title: "Budget"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes append values through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{update: %{table_range: "Sheet1!A1:B2", updated_range: "Sheet1!A3:B3"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.append",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2", values: [["A", 1]]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes clear values through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{update: %{cleared_range: "Sheet1!A1:B2"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.clear",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch update values through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              batch_update: %{
                spreadsheet_id: "sheet123",
                total_updated_cells: 2,
                responses: [%{updated_range: "Sheet1!A1:B2"}]
              }
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_update",
               %{
                 spreadsheet_id: "sheet123",
                 data: [%{range: "Sheet1!A1:B2", values: [["Name", "Count"]]}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch clear values through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{batch_clear: %{cleared_ranges: ["Sheet1!A1:B2"]}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_clear",
               %{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch update values by data filter through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              batch_update: %{
                spreadsheet_id: "sheet123",
                total_updated_cells: 2,
                responses: [%{updated_range: "Sheet1!A1:B2"}]
              }
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_update_by_data_filter",
               %{
                 spreadsheet_id: "sheet123",
                 data: [%{data_filter: %{a1Range: "Sheet1!A1:B2"}, values: [["Name", "Count"]]}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch clear values by data filter through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{batch_clear: %{cleared_ranges: ["Sheet1!A1:B2"]}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_clear_by_data_filter",
               %{spreadsheet_id: "sheet123", data_filters: [%{a1Range: "Sheet1!A1:B2"}]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes developer metadata actions through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{developer_metadata: %{metadata_id: 123, metadata_key: "sync_id"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.developer_metadata.get",
               %{spreadsheet_id: "sheet123", metadata_id: 123},
               context: context,
               credential_lease: lease
             )

    assert {:ok,
            %{
              matched_developer_metadata: [
                %{developer_metadata: %{metadata_id: 123, metadata_key: "sync_id"}}
              ]
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.developer_metadata.search",
               %{
                 spreadsheet_id: "sheet123",
                 data_filters: [%{developerMetadataLookup: %{metadataKey: "sync_id"}}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes add sheet through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{sheet: %{sheet_id: 123, title: "Forecast"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.sheet.add",
               %{spreadsheet_id: "sheet123", title: "Forecast"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete sheet through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{spreadsheet_id: "sheet123", sheet_id: 123}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.sheet.delete",
               %{spreadsheet_id: "sheet123", sheet_id: 123},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes rename sheet through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{sheet: %{sheet_id: 123, title: "Renamed"}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.sheet.rename",
               %{spreadsheet_id: "sheet123", sheet_id: 123, title: "Renamed"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch update through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{batch_update: %{spreadsheet_id: "sheet123", replies: [%{}]}}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.batch_update",
               %{
                 spreadsheet_id: "sheet123",
                 requests: [%{repeatCell: %{fields: "userEnteredFormat.textFormat.bold"}}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "batch update validates request shape before client execution" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_batch_update_request,
              details: %{index: 0}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.batch_update",
               %{spreadsheet_id: "sheet123", requests: [%{repeatCell: %{}, deleteSheet: %{}}]},
               context: context,
               credential_lease: lease
             )
  end

  test "batch value update validates range data before client execution" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_batch_update_values_entry,
              details: %{index: 0}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_update",
               %{spreadsheet_id: "sheet123", data: [%{range: "", values: [["Name"]]}]},
               context: context,
               credential_lease: lease
             )
  end

  test "batch get validates ranges before client execution" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_batch_get_values_ranges,
              details: %{expected: "non-empty list"}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_get",
               %{spreadsheet_id: "sheet123", ranges: []},
               context: context,
               credential_lease: lease
             )
  end

  test "batch clear validates ranges before client execution" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_batch_clear_values_ranges,
              details: %{expected: "non-empty A1 range strings"}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_clear",
               %{spreadsheet_id: "sheet123", ranges: [""]},
               context: context,
               credential_lease: lease
             )
  end

  test "data-filter actions validate provider data filters before client execution" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_data_filters,
              details: %{expected: "non-empty list with exactly one DataFilter selector per map"}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_get_by_data_filter",
               %{
                 spreadsheet_id: "sheet123",
                 data_filters: [%{a1Range: "Sheet1!A1:B2", gridRange: %{sheetId: 0}}]
               },
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_data_filters}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.spreadsheet.get_by_data_filter",
               %{spreadsheet_id: "sheet123", data_filters: []},
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_data_filters}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_clear_by_data_filter",
               %{spreadsheet_id: "sheet123", data_filters: [%{}]},
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_data_filters}} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.developer_metadata.search",
               %{spreadsheet_id: "sheet123", data_filters: [%{gridRange: %{}}]},
               context: context,
               credential_lease: lease
             )
  end

  test "batch update by data filter validates data entries before client execution" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_batch_update_by_data_filter_entry,
              details: %{index: 0}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_update_by_data_filter",
               %{spreadsheet_id: "sheet123", data: [%{data_filter: %{a1Range: ""}, values: []}]},
               context: context,
               credential_lease: lease
             )
  end

  test "batch value update validates non-empty data before client execution" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_batch_update_values_data,
              details: %{expected: "non-empty list"}
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_update",
               %{spreadsheet_id: "sheet123", data: []},
               context: context,
               credential_lease: lease
             )
  end

  test "fails before handler execution when required Sheets scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"]
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.spreadsheet.get",
               %{spreadsheet_id: "sheet123"},
               context: context,
               credential_lease: lease
             )
  end

  test "write actions require full Sheets scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/spreadsheets"]
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.update",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2", values: [["Name", "Count"]]},
               context: context,
               credential_lease: lease
             )
  end

  test "data-filter reads require full Sheets scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/spreadsheets"]
            }} =
             Connect.invoke(
               Sheets.integration(),
               "google.sheets.values.batch_get_by_data_filter",
               %{spreadsheet_id: "sheet123", data_filters: [%{a1Range: "Sheet1!A1:B2"}]},
               context: context,
               credential_lease: lease
             )
  end

  defp write_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/spreadsheets"
    ]
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/spreadsheets.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_sheets_client: FakeSheetsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
