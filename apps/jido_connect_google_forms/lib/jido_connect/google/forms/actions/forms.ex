defmodule Jido.Connect.Google.Forms.Actions.Forms do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/forms.body.readonly"
  @write_scope "https://www.googleapis.com/auth/forms.body"
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

        field(:include_linked_sheets, :boolean,
          example: true,
          description: "Whether to include linked sheet information in the response."
        )
      end

      output do
        field(:form, :map)
      end
    end

    action :create_form do
      id("google.forms.form.create")
      resource(:form)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create form")
      description("Create a new Google Forms form with a title and optional description.")
      handler(Jido.Connect.Google.Forms.Handlers.Actions.CreateForm)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:title, :string, required?: true, example: "Customer Survey")

        field(:description, :string,
          example: "Tell us what you think.",
          description: "Optional description for the new form."
        )
      end

      output do
        field(:form, :map)
      end
    end

    action :batch_update_form do
      id("google.forms.form.batch_update")
      resource(:form)
      verb(:update)
      data_classification(:workspace_content)
      label("Batch update form")

      description(
        "Run a validated Google Forms batchUpdate request for item, settings, and style operations."
      )

      handler(Jido.Connect.Google.Forms.Handlers.Actions.BatchUpdateForm)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string, required?: true, example: "1abc...")

        field(:requests, {:array, :map},
          required?: true,
          description:
            "List of batch update operations. Each map must contain exactly one operation key."
        )

        field(:write_control, :map,
          description: "Optional write control for concurrency control."
        )
      end

      output do
        field(:form, :map)
        field(:replies, {:array, :map})
      end
    end
  end
end
