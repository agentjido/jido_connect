defmodule Jido.Connect.Google.Contacts.Triggers.People do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  triggers do
    poll :person_changed do
      id("google.contacts.person.changed")
      resource(:person)
      verb(:watch)
      data_classification(:personal_data)
      label("Contact changed")
      description("Poll Google Contacts people changes using People connections sync tokens.")
      interval_ms(300_000)
      checkpoint(:sync_token)
      dedupe(%{key: [:resource_name, :etag]})
      handler(Jido.Connect.Google.Contacts.Handlers.Triggers.PersonChangedPoller)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:resource_name, :string, default: "people/me")
        field(:page_size, :integer, default: 100)
        field(:person_fields, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
      end

      signal do
        field(:resource_name, :string)
        field(:person_id, :string)
        field(:etag, :string)
        field(:deleted, :boolean)
        field(:display_name, :string)
        field(:person, :map)
      end
    end
  end
end
