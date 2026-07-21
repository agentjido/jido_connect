defmodule Jido.Connect.Intercom.Triggers.Contacts do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Intercom.ScopeResolver

  triggers do
    webhook :contact_created do
      id("intercom.contact.created")
      resource(:contact)
      verb(:watch)
      data_classification(:personal_data)
      label("Contact created")

      description("Receive Intercom webhook notifications when a new contact is created.")

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.ContactCreatedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["contacts:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:contact_id, :string)
        field(:contact_name, :string)
        field(:contact_email, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end

    webhook :contact_updated do
      id("intercom.contact.updated")
      resource(:contact)
      verb(:watch)
      data_classification(:personal_data)
      label("Contact updated")

      description("Receive Intercom webhook notifications when a contact is updated.")

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.ContactUpdatedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["contacts:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:contact_id, :string)
        field(:contact_name, :string)
        field(:contact_email, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end

    webhook :contact_deleted do
      id("intercom.contact.deleted")
      resource(:contact)
      verb(:watch)
      data_classification(:personal_data)
      label("Contact deleted")

      description("Receive Intercom webhook notifications when a contact is deleted.")

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.ContactDeletedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["contacts:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:contact_id, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end
  end
end
