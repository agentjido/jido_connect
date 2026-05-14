defmodule Jido.Connect.Google.Sheets.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Sheets

  defmodule FakeSheetsClient do
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
         updated_cells: 2
       })}
    end
  end

  test "readonly pack restricts search and describe to read tools" do
    results =
      Catalog.search_tools("sheets",
        modules: [Sheets],
        packs: Sheets.catalog_packs(),
        pack: :google_sheets_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.sheets.spreadsheet.get" in ids
    assert "google.sheets.values.get" in ids
    assert "google.sheets.values.batch_get" in ids
    refute "google.sheets.values.batch_get_by_data_filter" in ids
    refute "google.sheets.developer_metadata.search" in ids
    refute "google.sheets.values.update" in ids
    refute "google.sheets.spreadsheet.create" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.sheets.values.get",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_readonly
             )

    assert descriptor.tool.id == "google.sheets.values.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.sheets.values.update",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_readonly
             )
  end

  test "writer pack allows common writes but rejects raw batch update" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.sheets.values.update",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_writer
             )

    assert descriptor.tool.id == "google.sheets.values.update"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.sheets.values.batch_update",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_writer
             )

    assert descriptor.tool.id == "google.sheets.values.batch_update"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.sheets.values.batch_get_by_data_filter",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_writer
             )

    assert descriptor.tool.id == "google.sheets.values.batch_get_by_data_filter"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.sheets.developer_metadata.search",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_writer
             )

    assert descriptor.tool.id == "google.sheets.developer_metadata.search"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.sheets.batch_update",
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_writer
             )
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok, %{update: %{updated_cells: 2}}} =
             Catalog.call_tool(
               "google.sheets.values.update",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2", values: [["Name", "Count"]]},
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_writer,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.sheets.values.update",
               %{spreadsheet_id: "sheet123", range: "Sheet1!A1:B2", values: [["Name", "Count"]]},
               modules: [Sheets],
               packs: Sheets.catalog_packs(),
               pack: :google_sheets_readonly,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease do
    scopes = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/spreadsheets"
    ]

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
