defmodule Jido.Connect.Google.Contacts.Actions.OtherContacts do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_other_readonly_scope "https://www.googleapis.com/auth/contacts.other.readonly"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  actions do
    action :list_other_contacts do
      id("google.contacts.other.list")
      resource(:other_contact)
      verb(:list)
      data_classification(:personal_data)
      label("List other contacts")
      description("List the authenticated user's Google Other contacts.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.ListOtherContacts)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_other_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:read_mask, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
        field(:request_sync_token, :boolean, default: false)
        field(:sync_token, :string)
      end

      output do
        field(:people, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
        field(:total_size, :integer)
      end
    end

    action :search_other_contacts do
      id("google.contacts.other.search")
      resource(:other_contact)
      verb(:search)
      data_classification(:personal_data)
      label("Search other contacts")
      description("Search the authenticated user's Google Other contacts.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.SearchOtherContacts)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_other_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, required?: true, example: "Ada")
        field(:page_size, :integer, default: 10)
        field(:read_mask, :string)
        field(:fields, :string)
      end

      output do
        field(:people, {:array, :map})
      end
    end

    action :copy_other_contact do
      id("google.contacts.other.copy")
      resource(:other_contact)
      verb(:create)
      data_classification(:personal_data)
      label("Copy other contact")
      description("Copy a Google Other contact into the user's myContacts group.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.CopyOtherContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_other_readonly_scope, @contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "otherContacts/c123")
        field(:copy_mask, :string)
        field(:read_mask, :string)
        field(:sources, {:array, :string})
      end

      output do
        field(:person, :map)
      end
    end
  end
end
