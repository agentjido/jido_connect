defmodule Jido.Connect.Google.Forms.Actions.Forms do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/forms.body.readonly"
  @scope_resolver Jido.Connect.Google.Forms.ScopeResolver

  actions do
    action :get_form do
      id("google.forms.form.get")
      resource(:form)
      verb(:get)
      data_classification(:workspace_content)
      label("Get form")
      description("Fetch a Google Forms form by form id.")
      handler(Jido.Connect.Google.Forms.Handlers.Actions.GetForm)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string, required?: true, example: "1abc...")
      end

      output do
        field(:form, :map)
      end
    end
  end
end
