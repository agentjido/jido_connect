defmodule Jido.Connect.Salesforce.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Salesforce.ScopeResolver

  actions do
    # -----------------------------------------------------------------------
    # Contact read actions
    # -----------------------------------------------------------------------

    action :get_contact do
      id("salesforce.contacts.contact.get")
      resource(:contact)
      verb(:get)
      data_classification(:personal_data)
      label("Get contact")
      description("Fetch a Salesforce contact by ID.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.GetContact)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:contact_id, :string, required?: true, example: "0035g00000ABCdE")
        field(:fields, {:array, :string})
      end

      output do
        field(:contact, :map)
      end
    end

    action :list_contacts do
      id("salesforce.contacts.contact.list")
      resource(:contact)
      verb(:list)
      data_classification(:personal_data)
      label("List contacts")
      description("List Salesforce contacts using SOQL query.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.ListContacts)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:fields, {:array, :string})
        field(:where, :string)
        field(:limit, :integer, default: 100)
        field(:offset, :integer)
      end

      output do
        field(:contacts, {:array, :map})
        field(:pagination, :map)
      end
    end
  end
end
