defmodule Jido.Connect.Google.SearchConsole.Actions.URLInspection do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @scope_resolver Jido.Connect.Google.SearchConsole.ScopeResolver

  actions do
    action :inspect_url do
      id("google.search_console.url_inspection.inspect")
      resource(:url_inspection)
      verb(:read)
      data_classification(:workspace_metadata)
      label("Inspect Search Console URL")
      description("Inspect a URL for index status, mobile usability, and rich results.")

      handler(Jido.Connect.Google.SearchConsole.Handlers.Actions.InspectURL)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:site_url, :string,
          required?: true,
          example: "https://example.com/"
        )

        field(:inspection_url, :string,
          required?: true,
          example: "https://example.com/page"
        )

        field(:language_code, :string, example: "en-US")
      end

      output do
        field(:inspection, :map)
      end
    end
  end
end
