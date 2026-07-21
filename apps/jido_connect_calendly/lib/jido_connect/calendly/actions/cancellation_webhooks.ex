defmodule Jido.Connect.Calendly.Actions.CancellationWebhooks do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calendly.ScopeResolver

  actions do
    # -----------------------------------------------------------------------
    # Cancellation actions
    # -----------------------------------------------------------------------

    action :cancel_invitee do
      id("calendly.invitees.cancel")
      resource(:invitee)
      verb(:update)
      data_classification(:personal_data)
      label("Cancel invitee")

      description(
        "Cancel a Calendly invitee by event URI and invitee URI with an optional reason."
      )

      handler(Jido.Connect.Calendly.Handlers.Actions.CancelInvitee)
      effect(:external_write, confirmation: :always)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:event_uri, :string, required?: true)
        field(:uri, :string, required?: true)
        field(:reason, :string)
      end

      output do
        field(:invitee, :map)
      end

      metadata(%{
        risk_tags: [:cancellation, :mutation],
        risk_notes: "Irreversibly cancels an invitee's scheduled booking."
      })
    end

    # -----------------------------------------------------------------------
    # Webhook subscription actions
    # -----------------------------------------------------------------------

    action :create_webhook do
      id("calendly.webhooks.create")
      resource(:webhook_subscription)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create webhook subscription")
      description("Register a new Calendly webhook subscription endpoint.")
      handler(Jido.Connect.Calendly.Handlers.Actions.CreateWebhook)
      effect(:external_write, confirmation: :always)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:callback_url, :string,
          required?: true,
          example: "https://example.com/calendly/webhook"
        )

        field(:events, {:array, :string},
          required?: true,
          example: ["invitee.created", "invitee.canceled"]
        )

        field(:organization_uri, :string)
        field(:user_uri, :string)
        field(:scope, :string)
      end

      output do
        field(:webhook, :map)
      end

      metadata(%{
        risk_tags: [:webhook, :mutation],
        risk_notes: "Creates a webhook that receives event payloads from Calendly."
      })
    end

    action :list_webhooks do
      id("calendly.webhooks.list")
      resource(:webhook_subscription)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List webhook subscriptions")
      description("List Calendly webhook subscriptions with optional organization/user scope.")
      handler(Jido.Connect.Calendly.Handlers.Actions.ListWebhooks)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:organization_uri, :string)
        field(:user_uri, :string)
        field(:count, :integer, default: 20)
        field(:page_token, :string)
        field(:sort, :string)
      end

      output do
        field(:webhooks, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :delete_webhook do
      id("calendly.webhooks.delete")
      resource(:webhook_subscription)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete webhook subscription")
      description("Delete a Calendly webhook subscription by URI.")
      handler(Jido.Connect.Calendly.Handlers.Actions.DeleteWebhook)
      effect(:external_write, confirmation: :always)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:uri, :string,
          required?: true,
          example: "https://api.calendly.com/webhook_subscriptions/abc123"
        )
      end

      output do
        field(:webhook, :map)
      end

      metadata(%{
        risk_tags: [:webhook, :mutation],
        risk_notes: "Permanently removes a webhook subscription."
      })
    end
  end
end
