defmodule Jido.Connect.HubSpot.Triggers.Contacts do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_read_scope "crm.objects.contacts.read"
  @scope_resolver Jido.Connect.HubSpot.ScopeResolver

  triggers do
    poll :contact_changed do
      id("hubspot.contacts.contact.changed")
      resource(:contact)
      verb(:watch)
      data_classification(:personal_data)
      label("Contact changed")

      description(
        "Poll HubSpot CRM for contact changes using lastmodifieddate timestamp checkpoints."
      )

      interval_ms(300_000)
      checkpoint(:lastmodifieddate)
      dedupe(%{key: [:contact_id, :updated_at]})
      handler(Jido.Connect.HubSpot.Handlers.Triggers.ContactChangedPoller)

      access do
        auth(:private_app_token)
        scopes([@contacts_read_scope], resolver: @scope_resolver)
      end

      config do
        field(:limit, :integer,
          default: 100,
          description: "Maximum number of contacts to return per page (1–100)."
        )

        field(:properties, {:array, :string},
          description: "Contact properties to include in the response."
        )
      end

      signal do
        field(:contact_id, :string)
        field(:email, :string)
        field(:first_name, :string)
        field(:last_name, :string)
        field(:change_type, :string)
        field(:updated_at, :string)
        field(:archived?, :boolean)
        field(:contact, :map)
      end
    end

    webhook :contact_changed_push do
      id("hubspot.contacts.contact.changed.push")
      resource(:contact)
      verb(:watch)
      data_classification(:personal_data)
      label("Contact changed push")
      description("Receive HubSpot webhook notifications for contact changes.")

      verification(%{
        kind: :hubspot_webhook,
        signature: :hmac_sha256,
        header: "x-hubspot-signature"
      })

      dedupe(%{key: [:event_id]})
      handler(Jido.Connect.HubSpot.Handlers.Triggers.ContactChangedWebhook)

      access do
        auth(:private_app_token)
        scopes([@contacts_read_scope], resolver: @scope_resolver)
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
