defmodule Jido.Connect.Google.Contacts.Actions.Batch do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  actions do
    action :batch_get_people do
      id("google.contacts.person.batch_get")
      resource(:person)
      verb(:get)
      data_classification(:personal_data)
      label("Batch get people")
      description("Fetch multiple Google People API person resources by resource name.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.BatchGetPeople)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_names, {:array, :string}, required?: true)
        field(:person_fields, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
      end

      output do
        field(:people, {:array, :map})
        field(:responses, {:array, :map})
      end
    end

    action :batch_create_contacts do
      id("google.contacts.person.batch_create")
      resource(:person)
      verb(:create)
      data_classification(:personal_data)
      label("Batch create contacts")
      description("Create multiple Google Contacts people in one People API request.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.BatchCreateContacts)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:contacts, {:array, :map}, required?: true)
        field(:person_fields, :string)
        field(:sources, {:array, :string})
      end

      output do
        field(:people, {:array, :map})
        field(:responses, {:array, :map})
      end
    end

    action :batch_update_contacts do
      id("google.contacts.person.batch_update")
      resource(:person)
      verb(:update)
      data_classification(:personal_data)
      label("Batch update contacts")
      description("Update multiple Google Contacts people in one People API request.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.BatchUpdateContacts)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:contacts, {:array, :map}, required?: true)
        field(:update_person_fields, :string)
        field(:person_fields, :string)
        field(:sources, {:array, :string})
      end

      output do
        field(:people, {:array, :map})
        field(:responses, :map)
      end
    end

    action :batch_delete_contacts do
      id("google.contacts.person.batch_delete")
      resource(:person)
      verb(:delete)
      data_classification(:personal_data)
      label("Batch delete contacts")
      description("Delete multiple Google Contacts people in one People API request.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.BatchDeleteContacts)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_names, {:array, :string}, required?: true)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
