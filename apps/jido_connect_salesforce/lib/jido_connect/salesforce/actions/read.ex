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

    # -----------------------------------------------------------------------
    # Generic SObject query / read actions
    # -----------------------------------------------------------------------

    action :query do
      id("salesforce.crm.query")
      resource(:sobject)
      verb(:list)
      data_classification(:workspace_content)
      label("SOQL query")
      description("Execute a SOQL query against Salesforce.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.Query)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:soql, :string, required?: true, example: "SELECT Id, Name FROM Account LIMIT 10")
      end

      output do
        field(:records, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :get_record do
      id("salesforce.crm.record.get")
      resource(:sobject)
      verb(:get)
      data_classification(:workspace_content)
      label("Get record")
      description("Fetch a Salesforce record by SObject type and ID.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.GetRecord)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:sobject_type, :string, required?: true, example: "Account")
        field(:record_id, :string, required?: true, example: "0015g00000XYZaA")
        field(:fields, {:array, :string})
      end

      output do
        field(:record, :map)
      end
    end

    action :describe_object do
      id("salesforce.crm.object.describe")
      resource(:sobject)
      verb(:read)
      data_classification(:tool_metadata)
      label("Describe object")
      description("Describe a Salesforce SObject's metadata including fields.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.DescribeObject)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:sobject_type, :string, required?: true, example: "Contact")
      end

      output do
        field(:metadata, :map)
      end
    end

    action :list_recent do
      id("salesforce.crm.record.list_recent")
      resource(:sobject)
      verb(:list)
      data_classification(:workspace_content)
      label("List recent records")
      description("List recently modified Salesforce records for an SObject type.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.ListRecent)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:sobject_type, :string, required?: true, example: "Account")
        field(:fields, {:array, :string})
        field(:limit, :integer, default: 100)
      end

      output do
        field(:records, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :query_more do
      id("salesforce.crm.query_more")
      resource(:sobject)
      verb(:list)
      data_classification(:workspace_content)
      label("Query more")
      description("Fetch the next page of a paginated SOQL query result using nextRecordsUrl.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.QueryMore)
      effect(:read)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:next_records_url, :string,
          required?: true,
          example: "/services/data/v60.0/query/01g5g00000QRS-2000"
        )
      end

      output do
        field(:records, {:array, :map})
        field(:pagination, :map)
      end
    end
  end
end
