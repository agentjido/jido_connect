defmodule Jido.Connect.HubSpot.Triggers.Deals do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @deals_read_scope "crm.objects.deals.read"
  @scope_resolver Jido.Connect.HubSpot.ScopeResolver

  triggers do
    poll :deal_changed do
      id("hubspot.deals.deal.changed")
      resource(:deal)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Deal changed")

      description(
        "Poll HubSpot CRM for deal changes using lastmodifieddate timestamp checkpoints."
      )

      interval_ms(300_000)
      checkpoint(:lastmodifieddate)
      dedupe(%{key: [:deal_id, :updated_at]})
      handler(Jido.Connect.HubSpot.Handlers.Triggers.DealChangedPoller)

      access do
        auth(:private_app_token)
        scopes([@deals_read_scope], resolver: @scope_resolver)
      end

      config do
        field(:limit, :integer,
          default: 100,
          description: "Maximum number of deals to return per page (1–100)."
        )

        field(:properties, {:array, :string},
          description: "Deal properties to include in the response."
        )
      end

      signal do
        field(:deal_id, :string)
        field(:deal_name, :string)
        field(:amount, :integer)
        field(:deal_stage, :string)
        field(:pipeline, :string)
        field(:change_type, :string)
        field(:updated_at, :string)
        field(:archived?, :boolean)
        field(:deal, :map)
      end
    end

    webhook :deal_changed_push do
      id("hubspot.deals.deal.changed.push")
      resource(:deal)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Deal changed push")
      description("Receive HubSpot webhook notifications for deal changes.")

      verification(%{
        kind: :hubspot_webhook,
        signature: :hmac_sha256,
        header: "x-hubspot-signature"
      })

      dedupe(%{key: [:event_id]})
      handler(Jido.Connect.HubSpot.Handlers.Triggers.DealChangedWebhook)

      access do
        auth(:private_app_token)
        scopes([@deals_read_scope], resolver: @scope_resolver)
      end

      config do
        field(:app_id, :string, description: "HubSpot app ID for webhook subscription.")
      end

      signal do
        field(:event_id, :string)
        field(:subscription_id, :string)
        field(:portal_id, :string)
        field(:object_id, :string)
        field(:object_type, :string)
        field(:event_type, :string)
        field(:change_type, :string)
        field(:property_name, :string)
        field(:property_value, :string)
        field(:change_source, :string)
        field(:occurred_at, :string)
      end
    end
  end
end
