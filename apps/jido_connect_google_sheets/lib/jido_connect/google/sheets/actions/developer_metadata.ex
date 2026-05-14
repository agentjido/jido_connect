defmodule Jido.Connect.Google.Sheets.Actions.DeveloperMetadata do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @write_scope "https://www.googleapis.com/auth/spreadsheets"
  @scope_resolver Jido.Connect.Google.Sheets.ScopeResolver

  actions do
    action :get_developer_metadata do
      id "google.sheets.developer_metadata.get"
      resource :developer_metadata
      verb :get
      data_classification :workspace_metadata
      label "Get developer metadata"
      description "Fetch a Google Sheets developer metadata entry by metadata id."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.GetDeveloperMetadata
      effect :read

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :metadata_id, :integer, required?: true, example: 123
      end

      output do
        field :developer_metadata, :map
      end
    end

    action :search_developer_metadata do
      id "google.sheets.developer_metadata.search"
      resource :developer_metadata
      verb :search
      data_classification :workspace_metadata
      label "Search developer metadata"
      description "Search Google Sheets developer metadata with provider-specific data filters."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.SearchDeveloperMetadata
      effect :read

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :data_filters, {:array, :map}, required?: true
      end

      output do
        field :matched_developer_metadata, {:array, :map}
      end
    end
  end
end
