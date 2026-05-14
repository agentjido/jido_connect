defmodule Jido.Connect.Google.Sheets.Actions.ManageSpreadsheets do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @write_scope "https://www.googleapis.com/auth/spreadsheets"
  @scope_resolver Jido.Connect.Google.Sheets.ScopeResolver

  actions do
    action :create_spreadsheet do
      id "google.sheets.spreadsheet.create"
      resource :spreadsheet
      verb :create
      data_classification :workspace_metadata
      label "Create spreadsheet"
      description "Create a Google Sheets spreadsheet with optional first-sheet sizing."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.CreateSpreadsheet
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :title, :string, required?: true, example: "Budget"
        field :locale, :string
        field :time_zone, :string
        field :sheet_title, :string, example: "Sheet1"
        field :row_count, :integer
        field :column_count, :integer
      end

      output do
        field :spreadsheet, :map
      end
    end
  end
end
