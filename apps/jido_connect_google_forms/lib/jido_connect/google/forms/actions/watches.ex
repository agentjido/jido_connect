defmodule Jido.Connect.Google.Forms.Actions.Watches do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @responses_readonly_scope "https://www.googleapis.com/auth/forms.responses.readonly"
  @scope_resolver Jido.Connect.Google.Forms.ScopeResolver
  @event_types Jido.Connect.Google.Forms.Client.Watches.event_types()

  actions do
    action :create_watch do
      id("google.forms.watch.create")
      resource(:watch)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Create form watch")
      description("Create a Google Forms watch to receive notifications on form events.")
      handler(Jido.Connect.Google.Forms.Handlers.Actions.CreateWatch)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@responses_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string,
          required?: true,
          example: "1ABCdefGHI",
          description: "The form ID to watch."
        )

        field(:event_type, :string,
          required?: true,
          enum: @event_types,
          description:
            "The event type to watch for. Currently only SCHEMA_RESPONSES is supported."
        )

        field(:target, :map, description: "Optional watch target configuration.")
      end

      output do
        field(:watch, :map)
      end
    end

    action :renew_watch do
      id("google.forms.watch.renew")
      resource(:watch)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Renew form watch")
      description("Renew an existing Google Forms watch to extend its expiration.")
      handler(Jido.Connect.Google.Forms.Handlers.Actions.RenewWatch)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@responses_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string,
          required?: true,
          example: "1ABCdefGHI",
          description: "The form ID that the watch belongs to."
        )

        field(:watch_id, :string,
          required?: true,
          example: "watch_abc123",
          description: "The watch ID to renew."
        )

        field(:target, :map, description: "Optional updated watch target configuration.")
      end

      output do
        field(:watch, :map)
      end
    end

    action :delete_watch do
      id("google.forms.watch.delete")
      resource(:watch)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete form watch")
      description("Delete a Google Forms watch to stop receiving notifications.")
      handler(Jido.Connect.Google.Forms.Handlers.Actions.DeleteWatch)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@responses_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:form_id, :string,
          required?: true,
          example: "1ABCdefGHI",
          description: "The form ID that the watch belongs to."
        )

        field(:watch_id, :string,
          required?: true,
          example: "watch_abc123",
          description: "The watch ID to delete."
        )
      end

      output do
        field(:result, :map)
      end
    end
  end
end
