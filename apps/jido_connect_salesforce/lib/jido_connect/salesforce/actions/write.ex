defmodule Jido.Connect.Salesforce.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Salesforce.ScopeResolver

  actions do
    # -----------------------------------------------------------------------
    # Contact write actions
    # -----------------------------------------------------------------------

    action :create_contact do
      id("salesforce.contacts.contact.create")
      resource(:contact)
      verb(:create)
      data_classification(:personal_data)
      label("Create contact")
      description("Create a new Salesforce contact.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.CreateContact)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:first_name, :string, example: "Bella")
        field(:last_name, :string, example: "Martinez")
        field(:email, :string, example: "bella@example.com")
        field(:phone, :string, example: "+1-555-0101")
        field(:title, :string, example: "Product Manager")
        field(:account_id, :string, example: "0015g00000XYZaA")
        field(:properties, :map, default: %{})
      end

      output do
        field(:contact_id, :string)
        field(:success, :boolean)
      end
    end
  end
end
