defmodule Jido.Connect.Calcom.Actions.Webhooks do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calcom.ScopeResolver

  actions do
    action :create_webhook do
      id("calcom.webhooks.create")
      resource(:webhook)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create Cal.com webhook")
      description("Register a new Cal.com webhook endpoint.")
      handler(Jido.Connect.Calcom.Handlers.Actions.CreateWebhook)
      effect(:external_write, confirmation: :always)

      access do
        auth(:api_key)
        scopes(["WEBHOOK_WRITE"], resolver: @scope_resolver)
      end

      input do
        field(:subscriber_url, :string,
          required?: true,
          example: "https://example.com/webhooks/calcom"
        )

        field(:triggers, {:array, :string},
          required?: true,
          example: ["BOOKING_CREATED", "BOOKING_CANCELLED"]
        )

        field(:active, :boolean, default: true)
        field(:payload_template, :string)
        field(:event_type_id, :integer)
        field(:secret, :string)
      end

      output do
        field(:webhook, :map)
      end
    end

    action :list_webhooks do
      id("calcom.webhooks.list")
      resource(:webhook)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Cal.com webhooks")
      description("List registered Cal.com webhook endpoints.")
      handler(Jido.Connect.Calcom.Handlers.Actions.ListWebhooks)
      effect(:read)

      access do
        auth(:api_key)
        scopes(["WEBHOOK_READ"], resolver: @scope_resolver)
      end

      input do
        field(:event_type_id, :integer)
      end

      output do
        field(:webhooks, {:array, :map})
      end
    end

    action :delete_webhook do
      id("calcom.webhooks.delete")
      resource(:webhook)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete Cal.com webhook")
      description("Delete a registered Cal.com webhook endpoint by ID.")
      handler(Jido.Connect.Calcom.Handlers.Actions.DeleteWebhook)
      effect(:external_write, confirmation: :always)

      access do
        auth(:api_key)
        scopes(["WEBHOOK_WRITE"], resolver: @scope_resolver)
      end

      input do
        field(:webhook_id, :integer,
          required?: true,
          example: 42
        )
      end

      output do
        field(:webhook, :map)
      end
    end
  end
end
