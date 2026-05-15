defmodule Jido.Connect.Google.Forms.Actions.Responses do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @responses_readonly_scope "https://www.googleapis.com/auth/forms.responses.readonly"
  @scope_resolver Jido.Connect.Google.Forms.ScopeResolver

  actions do
    action :list_responses do
      id("google.forms.responses.list")
      resource(:response)
      verb(:list)
      data_classification(:personal_data)
      label("List form responses")

      description(
        "List form responses for a Google Forms form with optional pagination and filtering."
      )

      handler(Jido.Connect.Google.Forms.Handlers.Actions.ListResponses)
      effect(:read)

      access do
        auth(:user)
        scopes([@responses_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string, required?: true, example: "1abc...")

        field(:page_size, :integer,
          default: 50,
          description: "Maximum number of responses to return per page."
        )

        field(:page_token, :string,
          description: "Page token from a previous list response to fetch the next page."
        )

        field(:filter, :string,
          description: "Optional filter expression (e.g., timestamp >= '2026-01-01')."
        )
      end

      output do
        field(:responses, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_response do
      id("google.forms.responses.get")
      resource(:response)
      verb(:get)
      data_classification(:personal_data)
      label("Get form response")
      description("Fetch a single form response by form id and response id.")
      handler(Jido.Connect.Google.Forms.Handlers.Actions.GetResponse)
      effect(:read)

      access do
        auth(:user)
        scopes([@responses_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string, required?: true, example: "1abc...")
        field(:response_id, :string, required?: true, example: "ACYDBNh...")
      end

      output do
        field(:response, :map)
      end
    end
  end
end
