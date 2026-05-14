defmodule Jido.Connect.Google.Sheets.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Sheets.{Client, Spreadsheet, ValueRange}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_sheets,
      :google_sheets_api_base_url,
      "https://sheets.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_sheets, :google_sheets_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets spreadsheet metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v4/spreadsheets/sheet123"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["ranges"] == "Sheet1!A1:B2"
      assert conn.query_params["includeGridData"] == "false"

      Req.Test.json(conn, spreadsheet_payload())
    end)

    assert {:ok, %Spreadsheet{} = spreadsheet} =
             Client.get_spreadsheet(
               %{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"], include_grid_data: false},
               "token"
             )

    assert spreadsheet.spreadsheet_id == "sheet123"
    assert spreadsheet.title == "Budget"
  end

  test "creates spreadsheet" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "properties" => %{"title" => "Budget", "timeZone" => "America/Chicago"},
               "sheets" => [
                 %{
                   "properties" => %{
                     "title" => "Plan",
                     "gridProperties" => %{"rowCount" => 100, "columnCount" => 20}
                   }
                 }
               ]
             }

      Req.Test.json(conn, spreadsheet_payload())
    end)

    assert {:ok, %Spreadsheet{} = spreadsheet} =
             Client.create_spreadsheet(
               %{
                 title: "Budget",
                 time_zone: "America/Chicago",
                 sheet_title: "Plan",
                 row_count: 100,
                 column_count: 20
               },
               "token"
             )

    assert spreadsheet.spreadsheet_id == "sheet123"
  end

  test "gets values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values/Sheet1%21A1%3AB2"
      assert conn.query_params["majorDimension"] == "ROWS"

      Req.Test.json(conn, %{
        "range" => "Sheet1!A1:B2",
        "majorDimension" => "ROWS",
        "values" => [["Name", "Count"], ["A", 1]]
      })
    end)

    assert {:ok, %ValueRange{} = value_range} =
             Client.get_values(
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2", major_dimension: "ROWS"},
               "token"
             )

    assert value_range.range == "Sheet1!A1:B2"
    assert value_range.values == [["Name", "Count"], ["A", 1]]
  end

  test "batch gets values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values:batchGet"
      assert conn.query_string =~ "ranges=Sheet1%21A1%3AB2"
      assert conn.query_string =~ "ranges=Sheet2%21A1%3AA1"
      assert conn.query_params["majorDimension"] == "ROWS"
      assert conn.query_params["valueRenderOption"] == "FORMATTED_VALUE"
      assert conn.query_params["dateTimeRenderOption"] == "FORMATTED_STRING"

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "valueRanges" => [
          %{"range" => "Sheet1!A1:B2", "majorDimension" => "ROWS", "values" => [["A"]]},
          %{"range" => "Sheet2!A1:A1", "majorDimension" => "ROWS", "values" => [["B"]]}
        ]
      })
    end)

    assert {:ok, result} =
             Client.batch_get_values(
               %{
                 spreadsheet_id: "sheet123",
                 ranges: ["Sheet1!A1:B2", "Sheet2!A1:A1"],
                 major_dimension: "ROWS",
                 value_render_option: "FORMATTED_VALUE",
                 date_time_render_option: "FORMATTED_STRING"
               },
               "token"
             )

    assert result.spreadsheet_id == "sheet123"

    assert [%ValueRange{range: "Sheet1!A1:B2"}, %ValueRange{range: "Sheet2!A1:A1"}] =
             result.value_ranges
  end

  test "rejects malformed batch get response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"spreadsheetId" => "sheet123", "valueRanges" => "bad"})
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.batch_get_values(
               %{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"]},
               "token"
             )
  end

  test "updates values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values/Sheet1%21A1%3AB2"
      assert conn.query_params["valueInputOption"] == "USER_ENTERED"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "majorDimension" => "ROWS",
               "range" => "Sheet1!A1:B2",
               "values" => [["Name", "Count"], ["A", 1]]
             }

      Req.Test.json(conn, update_payload())
    end)

    assert {:ok, update} =
             Client.update_values(
               %{
                 spreadsheet_id: "sheet123",
                 range: "Sheet1!A1:B2",
                 values: [["Name", "Count"], ["A", 1]],
                 value_input_option: "USER_ENTERED"
               },
               "token"
             )

    assert update.updated_range == "Sheet1!A1:B2"
    assert update.updated_cells == 4
  end

  test "batch updates values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "valueInputOption" => "USER_ENTERED",
               "data" => [
                 %{
                   "range" => "Sheet1!A1:B2",
                   "majorDimension" => "ROWS",
                   "values" => [["Name", "Count"]]
                 },
                 %{
                   "range" => "Sheet2!A1:A1",
                   "majorDimension" => "COLUMNS",
                   "values" => [["Total"]]
                 }
               ],
               "includeValuesInResponse" => true
             }

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "totalUpdatedRows" => 2,
        "totalUpdatedColumns" => 3,
        "totalUpdatedCells" => 3,
        "responses" => [
          %{"updatedRange" => "Sheet1!A1:B2", "updatedRows" => 1, "updatedCells" => 2},
          %{"updatedRange" => "Sheet2!A1:A1", "updatedRows" => 1, "updatedCells" => 1}
        ]
      })
    end)

    assert {:ok, result} =
             Client.batch_update_values(
               %{
                 spreadsheet_id: "sheet123",
                 value_input_option: "USER_ENTERED",
                 include_values_in_response: true,
                 data: [
                   %{range: "Sheet1!A1:B2", values: [["Name", "Count"]]},
                   %{range: "Sheet2!A1:A1", major_dimension: "COLUMNS", values: [["Total"]]}
                 ]
               },
               "token"
             )

    assert result.total_updated_cells == 3
    assert Enum.map(result.responses, & &1.updated_range) == ["Sheet1!A1:B2", "Sheet2!A1:A1"]
  end

  test "rejects malformed batch update values response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"spreadsheetId" => "sheet123", "responses" => "bad"})
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.batch_update_values(
               %{
                 spreadsheet_id: "sheet123",
                 data: [%{range: "Sheet1!A1:B2", values: [["Name"]]}]
               },
               "token"
             )
  end

  test "appends values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values/Sheet1%21A1%3AB2:append"
      assert conn.query_params["valueInputOption"] == "RAW"
      assert conn.query_params["insertDataOption"] == "INSERT_ROWS"

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "tableRange" => "Sheet1!A1:B2",
        "updates" => %{
          "updatedRange" => "Sheet1!A3:B3",
          "updatedRows" => 1,
          "updatedColumns" => 2,
          "updatedCells" => 2
        }
      })
    end)

    assert {:ok, update} =
             Client.append_values(
               %{
                 spreadsheet_id: "sheet123",
                 range: "Sheet1!A1:B2",
                 values: [["B", 2]],
                 insert_data_option: "INSERT_ROWS"
               },
               "token"
             )

    assert update.table_range == "Sheet1!A1:B2"
    assert update.updated_range == "Sheet1!A3:B3"
  end

  test "clears values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values/Sheet1%21A1%3AB2:clear"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{}

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "clearedRange" => "Sheet1!A1:B2"
      })
    end)

    assert {:ok, update} =
             Client.clear_values(%{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2"}, "token")

    assert update.cleared_range == "Sheet1!A1:B2"
  end

  test "batch clears values" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123/values:batchClear"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "ranges" => ["Sheet1!A1:B2", "Sheet2!A1:A1"]
             }

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "clearedRanges" => ["Sheet1!A1:B2", "Sheet2!A1:A1"]
      })
    end)

    assert {:ok, result} =
             Client.batch_clear_values(
               %{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2", "Sheet2!A1:A1"]},
               "token"
             )

    assert result.cleared_ranges == ["Sheet1!A1:B2", "Sheet2!A1:A1"]
  end

  test "rejects malformed batch clear response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.batch_clear_values(
               %{spreadsheet_id: "sheet123", ranges: ["Sheet1!A1:B2"]},
               "token"
             )
  end

  test "adds sheet" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "requests" => [
                 %{
                   "addSheet" => %{
                     "properties" => %{
                       "title" => "Forecast",
                       "gridProperties" => %{"rowCount" => 100, "columnCount" => 10}
                     }
                   }
                 }
               ]
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "replies" => [
          %{
            "addSheet" => %{
              "properties" => %{
                "sheetId" => 123,
                "title" => "Forecast",
                "index" => 1,
                "gridProperties" => %{"rowCount" => 100, "columnCount" => 10}
              }
            }
          }
        ]
      })
    end)

    assert {:ok, sheet} =
             Client.add_sheet(
               %{spreadsheet_id: "sheet123", title: "Forecast", row_count: 100, column_count: 10},
               "token"
             )

    assert sheet.sheet_id == 123
    assert sheet.title == "Forecast"
  end

  test "deletes sheet" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "requests" => [%{"deleteSheet" => %{"sheetId" => 123}}]
             }

      Req.Test.json(conn, %{"spreadsheetId" => "sheet123", "replies" => [%{}]})
    end)

    assert {:ok, %{spreadsheet_id: "sheet123", sheet_id: 123}} =
             Client.delete_sheet(%{spreadsheet_id: "sheet123", sheet_id: 123}, "token")
  end

  test "renames sheet" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "requests" => [
                 %{
                   "updateSheetProperties" => %{
                     "properties" => %{"sheetId" => 123, "title" => "Renamed"},
                     "fields" => "title"
                   }
                 }
               ]
             }

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "replies" => [
          %{
            "updateSheetProperties" => %{
              "properties" => %{"sheetId" => 123, "title" => "Renamed"}
            }
          }
        ]
      })
    end)

    assert {:ok, sheet} =
             Client.rename_sheet(
               %{spreadsheet_id: "sheet123", sheet_id: 123, title: "Renamed"},
               "token"
             )

    assert sheet.sheet_id == 123
    assert sheet.title == "Renamed"
  end

  test "runs batch update" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v4/spreadsheets/sheet123:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "requests" => [
                 %{
                   "repeatCell" => %{
                     "range" => %{"sheetId" => 123},
                     "fields" => "userEnteredFormat.textFormat.bold"
                   }
                 }
               ],
               "includeSpreadsheetInResponse" => true,
               "responseRanges" => ["Sheet1!A1:B2"]
             }

      Req.Test.json(conn, %{
        "spreadsheetId" => "sheet123",
        "replies" => [%{}],
        "updatedSpreadsheet" => %{"spreadsheetId" => "sheet123"}
      })
    end)

    assert {:ok, result} =
             Client.batch_update(
               %{
                 spreadsheet_id: "sheet123",
                 requests: [
                   %{
                     repeatCell: %{
                       range: %{sheetId: 123},
                       fields: "userEnteredFormat.textFormat.bold"
                     }
                   }
                 ],
                 include_spreadsheet_in_response: true,
                 response_ranges: ["Sheet1!A1:B2"]
               },
               "token"
             )

    assert result.spreadsheet_id == "sheet123"
    assert result.replies == [%{}]
    assert result.updated_spreadsheet == %{"spreadsheetId" => "sheet123"}
  end

  defp spreadsheet_payload do
    %{
      "spreadsheetId" => "sheet123",
      "properties" => %{"title" => "Budget"},
      "sheets" => [
        %{
          "properties" => %{
            "sheetId" => 0,
            "title" => "Sheet1",
            "index" => 0
          }
        }
      ]
    }
  end

  defp update_payload do
    %{
      "spreadsheetId" => "sheet123",
      "updatedRange" => "Sheet1!A1:B2",
      "updatedRows" => 2,
      "updatedColumns" => 2,
      "updatedCells" => 4
    }
  end
end
