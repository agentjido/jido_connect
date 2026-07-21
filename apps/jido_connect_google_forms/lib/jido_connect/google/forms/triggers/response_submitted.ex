defmodule Jido.Connect.Google.Forms.Triggers.ResponseSubmitted do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @responses_readonly_scope "https://www.googleapis.com/auth/forms.responses.readonly"
  @scope_resolver Jido.Connect.Google.Forms.ScopeResolver

  triggers do
    webhook :response_submitted do
      id("google.forms.response.submitted")
      resource(:watch)
      verb(:watch)
      data_classification(:personal_data)
      label("Form response submitted")

      description("Receive Google Forms notifications when a form response is submitted.")

      verification(%{
        kind: :google_pubsub_push,
        oidc: :host_verified,
        payload: :pubsub_message
      })

      dedupe(%{key: [:form_id, :watch_id]})
      handler(Jido.Connect.Google.Forms.Handlers.Triggers.ResponseSubmittedWebhook)

      access do
        auth(:user)
        scopes([@responses_readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:form_id, :string, required?: true)
        field(:watch_id, :string)
        field(:event_type, :string, default: "SCHEMA_RESPONSES")
      end

      signal do
        field(:form_id, :string)
        field(:watch_id, :string)
        field(:event_type, :string)
        field(:state, :string)
        field(:error_type, :string)
        field(:create_time, :string)
        field(:expire_time, :string)
        field(:delivery, :map)
      end
    end
  end
end
