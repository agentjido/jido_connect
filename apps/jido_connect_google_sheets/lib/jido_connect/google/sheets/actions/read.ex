defmodule Jido.Connect.Google.Sheets.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/spreadsheets.readonly"
  @scope_resolver Jido.Connect.Google.Sheets.ScopeResolver

  actions do
    action :get_spreadsheet do
      id "google.sheets.spreadsheet.get"
      resource :spreadsheet
      verb :get
      data_classification :workspace_metadata
      label "Get spreadsheet"
      description "Fetch Google Sheets spreadsheet metadata by spreadsheet id."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.GetSpreadsheet
      effect :read

      access do
        auth :user
        scopes [@readonly_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :ranges, {:array, :string}, default: []
        field :include_grid_data, :boolean, default: false
      end

      output do
        field :spreadsheet, :map
      end
    end

    action :get_values do
      id "google.sheets.values.get"
      resource :spreadsheet_values
      verb :get
      data_classification :workspace_content
      label "Get sheet values"
      description "Fetch values from a Google Sheets A1 range."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.GetValues
      effect :read

      access do
        auth :user
        scopes [@readonly_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :range, :string, required?: true, example: "Sheet1!A1:B2"
        field :major_dimension, :string, enum: ["ROWS", "COLUMNS"]
        field :value_render_option, :string
        field :date_time_render_option, :string
      end

      output do
        field :value_range, :map
      end
    end

    action :batch_get_values do
      id "google.sheets.values.batch_get"
      resource :spreadsheet_values
      verb :get
      data_classification :workspace_content
      label "Batch get sheet values"
      description "Fetch values from multiple Google Sheets A1 ranges."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchGetValues
      effect :read

      access do
        auth :user
        scopes [@readonly_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :ranges, {:array, :string}, required?: true, example: ["Sheet1!A1:B2"]
        field :major_dimension, :string, enum: ["ROWS", "COLUMNS"]
        field :value_render_option, :string
        field :date_time_render_option, :string
      end

      output do
        field :spreadsheet_id, :string
        field :value_ranges, {:array, :map}
      end
    end
  end
end
