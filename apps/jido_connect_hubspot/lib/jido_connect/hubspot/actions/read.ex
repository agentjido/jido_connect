defmodule Jido.Connect.HubSpot.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_read_scope "crm.objects.contacts.read"
  @companies_read_scope "crm.objects.companies.read"
  @deals_read_scope "crm.objects.deals.read"
  @scope_resolver Jido.Connect.HubSpot.ScopeResolver

  actions do
    # -----------------------------------------------------------------------
    # Contact actions
    # -----------------------------------------------------------------------

    action :get_contact do
      id("hubspot.contacts.contact.get")
      resource(:contact)
      verb(:get)
      data_classification(:personal_data)
      label("Get contact")
      description("Fetch a HubSpot CRM contact by ID.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.GetContact)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@contacts_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:contact_id, :string, required?: true, example: "501")
        field(:properties, {:array, :string})
        field(:properties_with_history, {:array, :string})
        field(:associations, {:array, :string})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:contact, :map)
      end
    end

    action :list_contacts do
      id("hubspot.contacts.contact.list")
      resource(:contact)
      verb(:list)
      data_classification(:personal_data)
      label("List contacts")
      description("List HubSpot CRM contacts with pagination and property selection.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.ListContacts)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@contacts_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer, default: 100)
        field(:after, :string)
        field(:properties, {:array, :string})
        field(:properties_with_history, {:array, :string})
        field(:associations, {:array, :string})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:contacts, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :search_contacts do
      id("hubspot.contacts.contact.search")
      resource(:contact)
      verb(:search)
      data_classification(:personal_data)
      label("Search contacts")
      description("Search HubSpot CRM contacts by query or filter groups.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.SearchContacts)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@contacts_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, example: "bella@example.com")
        field(:limit, :integer, default: 100)
        field(:after, :string)
        field(:properties, {:array, :string})
        field(:sorts, {:array, :map})
        field(:filter_groups, {:array, :map})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:contacts, {:array, :map})
        field(:pagination, :map)
      end
    end

    # -----------------------------------------------------------------------
    # Company actions
    # -----------------------------------------------------------------------

    action :get_company do
      id("hubspot.companies.company.get")
      resource(:company)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get company")
      description("Fetch a HubSpot CRM company by ID.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.GetCompany)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@companies_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:company_id, :string, required?: true, example: "201")
        field(:properties, {:array, :string})
        field(:properties_with_history, {:array, :string})
        field(:associations, {:array, :string})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:company, :map)
      end
    end

    action :list_companies do
      id("hubspot.companies.company.list")
      resource(:company)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List companies")
      description("List HubSpot CRM companies with pagination and property selection.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.ListCompanies)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@companies_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer, default: 100)
        field(:after, :string)
        field(:properties, {:array, :string})
        field(:properties_with_history, {:array, :string})
        field(:associations, {:array, :string})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:companies, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :search_companies do
      id("hubspot.companies.company.search")
      resource(:company)
      verb(:search)
      data_classification(:workspace_metadata)
      label("Search companies")
      description("Search HubSpot CRM companies by query or filter groups.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.SearchCompanies)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@companies_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, example: "Acme")
        field(:limit, :integer, default: 100)
        field(:after, :string)
        field(:properties, {:array, :string})
        field(:sorts, {:array, :map})
        field(:filter_groups, {:array, :map})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:companies, {:array, :map})
        field(:pagination, :map)
      end
    end

    # -----------------------------------------------------------------------
    # Deal actions
    # -----------------------------------------------------------------------

    action :get_deal do
      id("hubspot.deals.deal.get")
      resource(:deal)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get deal")
      description("Fetch a HubSpot CRM deal by ID.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.GetDeal)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@deals_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:deal_id, :string, required?: true, example: "301")
        field(:properties, {:array, :string})
        field(:properties_with_history, {:array, :string})
        field(:associations, {:array, :string})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:deal, :map)
      end
    end

    action :list_deals do
      id("hubspot.deals.deal.list")
      resource(:deal)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List deals")
      description("List HubSpot CRM deals with pagination and property selection.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.ListDeals)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@deals_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer, default: 100)
        field(:after, :string)
        field(:properties, {:array, :string})
        field(:properties_with_history, {:array, :string})
        field(:associations, {:array, :string})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:deals, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :search_deals do
      id("hubspot.deals.deal.search")
      resource(:deal)
      verb(:search)
      data_classification(:workspace_metadata)
      label("Search deals")
      description("Search HubSpot CRM deals by query or filter groups.")
      handler(Jido.Connect.HubSpot.Handlers.Actions.SearchDeals)
      effect(:read)

      access do
        auth(:private_app_token)
        scopes([@deals_read_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, example: "Enterprise")
        field(:limit, :integer, default: 100)
        field(:after, :string)
        field(:properties, {:array, :string})
        field(:sorts, {:array, :map})
        field(:filter_groups, {:array, :map})
        field(:archived, :boolean, default: false)
      end

      output do
        field(:deals, {:array, :map})
        field(:pagination, :map)
      end
    end
  end
end
