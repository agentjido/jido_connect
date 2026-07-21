defmodule Jido.Connect.HubSpot.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_write_scope "crm.objects.contacts.write"
  @deals_write_scope "crm.objects.deals.write"
  @scope_resolver Jido.Connect.HubSpot.ScopeResolver

  actions do
    # -----------------------------------------------------------------------
    # Contact write actions
    # -----------------------------------------------------------------------

    action :create_contact do
      id("hubspot.contacts.contact.create")
      resource(:contact)
      verb(:create)
      data_classification(:personal_data)
      label("Create contact")
      description("Create a new HubSpot CRM contact.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.CreateContact)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:private_app_token)
        scopes([@contacts_write_scope], resolver: @scope_resolver)
      end

      input do
        field(:email, :string, example: "bella@example.com")
        field(:first_name, :string, example: "Bella")
        field(:last_name, :string, example: "Martinez")
        field(:phone, :string, example: "+1-555-0101")
        field(:company, :string, example: "Acme Corp")
        field(:job_title, :string, example: "Product Manager")
        field(:website, :string, example: "https://example.com")
        field(:lifecycle_stage, :string, example: "lead")
        field(:properties, :map, default: %{})
      end

      output do
        field(:contact, :map)
      end
    end

    action :update_contact do
      id("hubspot.contacts.contact.update")
      resource(:contact)
      verb(:update)
      data_classification(:personal_data)
      label("Update contact")
      description("Update an existing HubSpot CRM contact by ID.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.UpdateContact)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:private_app_token)
        scopes([@contacts_write_scope], resolver: @scope_resolver)
      end

      input do
        field(:contact_id, :string, required?: true, example: "501")
        field(:email, :string, example: "bella@example.com")
        field(:first_name, :string, example: "Bella")
        field(:last_name, :string, example: "Martinez")
        field(:phone, :string, example: "+1-555-0101")
        field(:company, :string, example: "Acme Corp")
        field(:job_title, :string, example: "Product Manager")
        field(:website, :string, example: "https://example.com")
        field(:lifecycle_stage, :string, example: "customer")
        field(:properties, :map, default: %{})
      end

      output do
        field(:contact, :map)
      end
    end

    # -----------------------------------------------------------------------
    # Deal write actions
    # -----------------------------------------------------------------------

    action :create_deal do
      id("hubspot.deals.deal.create")
      resource(:deal)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create deal")
      description("Create a new HubSpot CRM deal.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.CreateDeal)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:private_app_token)
        scopes([@deals_write_scope], resolver: @scope_resolver)
      end

      input do
        field(:deal_name, :string, example: "Acme Enterprise License")
        field(:amount, :integer, example: 120_000)
        field(:deal_stage, :string, example: "contractsent")
        field(:pipeline, :string, example: "default")
        field(:close_date, :string, example: "2026-06-30T23:59:59Z")
        field(:deal_currency, :string, example: "USD")
        field(:owner_id, :string, example: "401")
        field(:description, :string, example: "Annual enterprise license deal")
        field(:deal_type, :string, example: "newbusiness")
        field(:properties, :map, default: %{})
      end

      output do
        field(:deal, :map)
      end
    end

    action :update_deal do
      id("hubspot.deals.deal.update")
      resource(:deal)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update deal")
      description("Update an existing HubSpot CRM deal by ID.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.UpdateDeal)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:private_app_token)
        scopes([@deals_write_scope], resolver: @scope_resolver)
      end

      input do
        field(:deal_id, :string, required?: true, example: "301")
        field(:deal_name, :string, example: "Acme Enterprise License")
        field(:amount, :integer, example: 120_000)
        field(:deal_stage, :string, example: "closedwon")
        field(:pipeline, :string, example: "default")
        field(:close_date, :string, example: "2026-06-30T23:59:59Z")
        field(:deal_currency, :string, example: "USD")
        field(:owner_id, :string, example: "401")
        field(:description, :string, example: "Annual enterprise license deal")
        field(:deal_type, :string, example: "newbusiness")
        field(:properties, :map, default: %{})
      end

      output do
        field(:deal, :map)
      end
    end

    # -----------------------------------------------------------------------
    # Note association actions
    # -----------------------------------------------------------------------

    action :create_note do
      id("hubspot.notes.note.create")
      resource(:note)
      verb(:create)
      data_classification(:workspace_content)
      label("Create note")

      description(
        "Create a HubSpot CRM note and optionally associate it with contacts, companies, deals, or tickets."
      )

      handler(Jido.Connect.HubSpot.Handlers.Actions.CreateNote)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:private_app_token)
        scopes([@contacts_write_scope, @deals_write_scope], resolver: @scope_resolver)
      end

      input do
        field(:body, :string, required?: true, example: "Had a great discovery call.")
        field(:owner_id, :string, example: "401")
        field(:contact_ids, {:array, :string}, default: [])
        field(:company_ids, {:array, :string}, default: [])
        field(:deal_ids, {:array, :string}, default: [])
        field(:ticket_ids, {:array, :string}, default: [])
      end

      output do
        field(:note, :map)
      end
    end
  end
end
