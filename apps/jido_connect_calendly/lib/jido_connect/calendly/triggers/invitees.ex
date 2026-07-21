defmodule Jido.Connect.Calendly.Triggers.Invitees do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calendly.ScopeResolver

  triggers do
    webhook :invitee_created do
      id("calendly.invitee.created")
      resource(:invitee)
      verb(:watch)
      data_classification(:personal_data)
      label("Invitee created")

      description(
        "Receive Calendly webhook notifications when a new invitee is created (booking confirmed)."
      )

      verification(%{
        kind: :calendly_webhook,
        signature: :hmac_sha256,
        header: "Calendly-Webhook-Signature"
      })

      dedupe(%{key: [:invitee_uri, :time]})
      handler(Jido.Connect.Calendly.Handlers.Triggers.InviteeCreatedWebhook)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      config do
        field(:webhook_id, :string, description: "Calendly webhook subscription URI.")
      end

      signal do
        field(:event_type, :string)
        field(:change_type, :string)
        field(:invitee_uri, :string)
        field(:invitee_email, :string)
        field(:invitee_name, :string)
        field(:invitee_status, :string)
        field(:invitee_timezone, :string)
        field(:event_uri, :string)
        field(:event_type_uri, :string)
        field(:event_type_name, :string)
        field(:organization_uri, :string)
        field(:cancel_url, :string)
        field(:reschedule_url, :string)
        field(:questions_and_answers, {:array, :map})
        field(:created_at, :string)
        field(:updated_at, :string)
        field(:time, :string)
      end
    end

    webhook :invitee_canceled do
      id("calendly.invitee.canceled")
      resource(:invitee)
      verb(:watch)
      data_classification(:personal_data)
      label("Invitee canceled")

      description("Receive Calendly webhook notifications when an invitee is canceled.")

      verification(%{
        kind: :calendly_webhook,
        signature: :hmac_sha256,
        header: "Calendly-Webhook-Signature"
      })

      dedupe(%{key: [:invitee_uri, :time]})
      handler(Jido.Connect.Calendly.Handlers.Triggers.InviteeCanceledWebhook)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      config do
        field(:webhook_id, :string, description: "Calendly webhook subscription URI.")
      end

      signal do
        field(:event_type, :string)
        field(:change_type, :string)
        field(:invitee_uri, :string)
        field(:invitee_email, :string)
        field(:invitee_name, :string)
        field(:invitee_status, :string)
        field(:invitee_timezone, :string)
        field(:event_uri, :string)
        field(:event_type_uri, :string)
        field(:event_type_name, :string)
        field(:organization_uri, :string)
        field(:canceled_by, :string)
        field(:cancellation_reason, :string)
        field(:cancel_url, :string)
        field(:reschedule_url, :string)
        field(:questions_and_answers, {:array, :map})
        field(:created_at, :string)
        field(:updated_at, :string)
        field(:time, :string)
      end
    end
  end
end
