defmodule Jido.Connect.Google.Sheets.Actions.DataFilters do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @write_scope "https://www.googleapis.com/auth/spreadsheets"
  @scope_resolver Jido.Connect.Google.Sheets.ScopeResolver

  actions do
    action :get_spreadsheet_by_data_filter do
      id "google.sheets.spreadsheet.get_by_data_filter"
      resource :spreadsheet
      verb :get
      data_classification :workspace_content
      label "Get spreadsheet by data filter"

      description "Fetch Google Sheets spreadsheet data intersecting provider-specific data filters."

      handler Jido.Connect.Google.Sheets.Handlers.Actions.GetSpreadsheetByDataFilter
      effect :read

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :data_filters, {:array, :map}, required?: true
        field :include_grid_data, :boolean, default: false
        field :exclude_tables_in_banded_ranges, :boolean, default: false
      end

      output do
        field :spreadsheet, :map
      end
    end

    action :batch_get_values_by_data_filter do
      id "google.sheets.values.batch_get_by_data_filter"
      resource :spreadsheet_values
      verb :get
      data_classification :workspace_content
      label "Batch get values by data filter"

      description "Fetch values from ranges matching provider-specific Google Sheets data filters."

      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchGetValuesByDataFilter
      effect :read

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :data_filters, {:array, :map}, required?: true
        field :major_dimension, :string, enum: ["ROWS", "COLUMNS"]
        field :value_render_option, :string
        field :date_time_render_option, :string
      end

      output do
        field :spreadsheet_id, :string
        field :value_ranges, {:array, :map}
      end
    end

    action :batch_update_values_by_data_filter do
      id "google.sheets.values.batch_update_by_data_filter"
      resource :spreadsheet_values
      verb :update
      data_classification :workspace_content
      label "Batch update values by data filter"

      description "Overwrite values in ranges matching provider-specific Google Sheets data filters."

      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchUpdateValuesByDataFilter
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :data, {:array, :map}, required?: true
        field :value_input_option, :string, enum: ["RAW", "USER_ENTERED"], default: "RAW"
        field :include_values_in_response, :boolean, default: false
        field :response_value_render_option, :string
        field :response_date_time_render_option, :string
      end

      output do
        field :batch_update, :map
      end
    end

    action :batch_clear_values_by_data_filter do
      id "google.sheets.values.batch_clear_by_data_filter"
      resource :spreadsheet_values
      verb :clear
      data_classification :workspace_content
      label "Batch clear values by data filter"

      description "Clear values from ranges matching provider-specific Google Sheets data filters."

      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchClearValuesByDataFilter
      effect :destructive, confirmation: :always

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :data_filters, {:array, :map}, required?: true
      end

      output do
        field :batch_clear, :map
      end
    end
  end
end
