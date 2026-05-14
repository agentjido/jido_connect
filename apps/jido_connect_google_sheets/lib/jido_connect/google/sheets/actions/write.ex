defmodule Jido.Connect.Google.Sheets.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @write_scope "https://www.googleapis.com/auth/spreadsheets"
  @scope_resolver Jido.Connect.Google.Sheets.ScopeResolver

  actions do
    action :update_values do
      id "google.sheets.values.update"
      resource :spreadsheet_values
      verb :update
      data_classification :workspace_content
      label "Update sheet values"
      description "Overwrite values in a Google Sheets A1 range."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.UpdateValues
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :range, :string, required?: true, example: "Sheet1!A1:B2"
        field :values, {:array, {:array, :any}}, required?: true
        field :major_dimension, :string, enum: ["ROWS", "COLUMNS"], default: "ROWS"
        field :value_input_option, :string, enum: ["RAW", "USER_ENTERED"], default: "RAW"
        field :include_values_in_response, :boolean, default: false
        field :response_value_render_option, :string
        field :response_date_time_render_option, :string
      end

      output do
        field :update, :map
      end
    end

    action :append_values do
      id "google.sheets.values.append"
      resource :spreadsheet_values
      verb :append
      data_classification :workspace_content
      label "Append sheet values"
      description "Append values after a Google Sheets table range."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.AppendValues
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :range, :string, required?: true, example: "Sheet1!A1:B2"
        field :values, {:array, {:array, :any}}, required?: true
        field :major_dimension, :string, enum: ["ROWS", "COLUMNS"], default: "ROWS"
        field :value_input_option, :string, enum: ["RAW", "USER_ENTERED"], default: "RAW"
        field :insert_data_option, :string, enum: ["OVERWRITE", "INSERT_ROWS"]
        field :include_values_in_response, :boolean, default: false
        field :response_value_render_option, :string
        field :response_date_time_render_option, :string
      end

      output do
        field :update, :map
      end
    end

    action :clear_values do
      id "google.sheets.values.clear"
      resource :spreadsheet_values
      verb :clear
      data_classification :workspace_content
      label "Clear sheet values"
      description "Clear values from a Google Sheets A1 range."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.ClearValues
      effect :destructive, confirmation: :always

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :range, :string, required?: true, example: "Sheet1!A1:B2"
      end

      output do
        field :update, :map
      end
    end

    action :batch_update_values do
      id "google.sheets.values.batch_update"
      resource :spreadsheet_values
      verb :update
      data_classification :workspace_content
      label "Batch update sheet values"
      description "Overwrite values in multiple Google Sheets A1 ranges."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchUpdateValues
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

    action :batch_clear_values do
      id "google.sheets.values.batch_clear"
      resource :spreadsheet_values
      verb :clear
      data_classification :workspace_content
      label "Batch clear sheet values"
      description "Clear values from multiple Google Sheets A1 ranges."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchClearValues
      effect :destructive, confirmation: :always

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :ranges, {:array, :string}, required?: true, example: ["Sheet1!A1:B2"]
      end

      output do
        field :batch_clear, :map
      end
    end
  end
end
