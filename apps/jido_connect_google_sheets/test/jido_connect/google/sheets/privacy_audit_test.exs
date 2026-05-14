defmodule Jido.Connect.Google.Sheets.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Sheets
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Sheets action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(Sheets, [
      action("google.sheets.spreadsheet.get", :workspace_metadata, :read, :none,
        text_includes: ["metadata"]
      ),
      action("google.sheets.values.get", :workspace_content, :read, :none,
        text_includes: ["sheet values", "range"]
      ),
      action("google.sheets.values.batch_get", :workspace_content, :read, :none,
        text_includes: ["values", "ranges"]
      ),
      action(
        "google.sheets.spreadsheet.get_by_data_filter",
        :workspace_content,
        :read,
        :none,
        text_includes: ["spreadsheet", "data filters"]
      ),
      action(
        "google.sheets.values.batch_get_by_data_filter",
        :workspace_content,
        :read,
        :none,
        text_includes: ["values", "data filters"]
      ),
      action("google.sheets.values.update", :workspace_content, :write, :required_for_ai,
        text_includes: ["sheet values"]
      ),
      action("google.sheets.values.append", :workspace_content, :write, :required_for_ai,
        text_includes: ["sheet values"]
      ),
      action("google.sheets.values.clear", :workspace_content, :destructive, :always,
        text_includes: ["sheet values"]
      ),
      action(
        "google.sheets.values.batch_update",
        :workspace_content,
        :write,
        :required_for_ai,
        text_includes: ["values", "ranges"]
      ),
      action(
        "google.sheets.values.batch_update_by_data_filter",
        :workspace_content,
        :write,
        :required_for_ai,
        text_includes: ["values", "data filters"]
      ),
      action("google.sheets.values.batch_clear", :workspace_content, :destructive, :always,
        text_includes: ["values", "ranges"]
      ),
      action(
        "google.sheets.values.batch_clear_by_data_filter",
        :workspace_content,
        :destructive,
        :always,
        text_includes: ["values", "data filters"]
      ),
      action("google.sheets.spreadsheet.create", :workspace_metadata, :write, :required_for_ai),
      action("google.sheets.developer_metadata.get", :workspace_metadata, :read, :none,
        text_includes: ["developer metadata"]
      ),
      action("google.sheets.developer_metadata.search", :workspace_metadata, :read, :none,
        text_includes: ["developer metadata", "data filters"]
      ),
      action("google.sheets.sheet.add", :workspace_metadata, :write, :required_for_ai),
      action("google.sheets.sheet.delete", :workspace_metadata, :destructive, :always),
      action("google.sheets.sheet.rename", :workspace_metadata, :write, :required_for_ai),
      action("google.sheets.batch_update", :workspace_content, :destructive, :always,
        text_includes: ["batch update"]
      )
    ])
  end

  defp action(id, classification, risk, confirmation, opts \\ []) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
