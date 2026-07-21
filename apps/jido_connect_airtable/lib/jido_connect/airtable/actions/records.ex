defmodule Jido.Connect.Airtable.Actions.Records do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Airtable.ScopeResolver

  actions do
    action :list_records do
      id("airtable.records.list")
      resource(:record)
      verb(:list)
      data_classification(:workspace_content)
      label("List records")
      description("List records from an Airtable table with optional filtering and sorting.")
      handler(Jido.Connect.Airtable.Handlers.Actions.ListRecords)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes(["data.records:read"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")
        field(:offset, :string)
        field(:page_size, :integer)
        field(:max_records, :integer)
        field(:view, :string)
        field(:fields, {:array, :string})
        field(:filter_by_formula, :string)
        field(:sort, {:array, :map})
      end

      output do
        field(:records, {:array, :map})
        field(:offset, :string)
      end
    end

    action :get_record do
      id("airtable.records.get")
      resource(:record)
      verb(:get)
      data_classification(:workspace_content)
      label("Get record")
      description("Fetch a single record from an Airtable table by ID.")
      handler(Jido.Connect.Airtable.Handlers.Actions.GetRecord)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes(["data.records:read"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")
        field(:record_id, :string, required?: true, example: "recXXXXXXXXXXXX")
      end

      output do
        field(:record, :map)
      end
    end

    action :create_record do
      id("airtable.records.create")
      resource(:record)
      verb(:create)
      data_classification(:workspace_content)
      label("Create record")
      description("Create a new record in an Airtable table.")
      handler(Jido.Connect.Airtable.Handlers.Actions.CreateRecord)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:personal_access_token)
        scopes(["data.records:write"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")
        field(:fields, :map, required?: true)
        field(:typecast, :boolean, default: false)
      end

      output do
        field(:record, :map)
      end
    end

    action :update_record do
      id("airtable.records.update")
      resource(:record)
      verb(:update)
      data_classification(:workspace_content)
      label("Update record")
      description("Update an existing record in an Airtable table.")
      handler(Jido.Connect.Airtable.Handlers.Actions.UpdateRecord)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:personal_access_token)
        scopes(["data.records:write"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")
        field(:record_id, :string, required?: true, example: "recXXXXXXXXXXXX")
        field(:fields, :map, required?: true)
        field(:typecast, :boolean, default: false)
      end

      output do
        field(:record, :map)
      end
    end

    action :delete_record do
      id("airtable.records.delete")
      resource(:record)
      verb(:delete)
      data_classification(:workspace_content)
      label("Delete record")
      description("Delete a record from an Airtable table.")
      handler(Jido.Connect.Airtable.Handlers.Actions.DeleteRecord)

      effect(:destructive, confirmation: :required_for_ai)

      access do
        auth(:personal_access_token)
        scopes(["data.records:write"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")
        field(:record_id, :string, required?: true, example: "recXXXXXXXXXXXX")
      end

      output do
        field(:record, :map)
      end
    end

    action :create_records do
      id("airtable.records.batch_create")
      resource(:record)
      verb(:create)
      data_classification(:workspace_content)
      label("Batch create records")
      description("Create up to 10 records in an Airtable table in a single request.")
      handler(Jido.Connect.Airtable.Handlers.Actions.CreateRecords)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:personal_access_token)
        scopes(["data.records:write"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")

        field(:records, {:array, :map},
          required?: true,
          description: "List of field maps, each keyed by Airtable field name."
        )

        field(:typecast, :boolean, default: false)
      end

      output do
        field(:records, {:array, :map})
      end
    end

    action :update_records do
      id("airtable.records.batch_update")
      resource(:record)
      verb(:update)
      data_classification(:workspace_content)
      label("Batch update records")
      description("Update up to 10 records in an Airtable table in a single request.")
      handler(Jido.Connect.Airtable.Handlers.Actions.UpdateRecords)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:personal_access_token)
        scopes(["data.records:write"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")

        field(:records, {:array, :map},
          required?: true,
          description: "List of maps with :id and :fields keys."
        )

        field(:typecast, :boolean, default: false)
      end

      output do
        field(:records, {:array, :map})
      end
    end

    action :delete_records do
      id("airtable.records.batch_delete")
      resource(:record)
      verb(:delete)
      data_classification(:workspace_content)
      label("Batch delete records")
      description("Delete up to 10 records from an Airtable table in a single request.")
      handler(Jido.Connect.Airtable.Handlers.Actions.DeleteRecords)

      effect(:destructive, confirmation: :required_for_ai)

      access do
        auth(:personal_access_token)
        scopes(["data.records:write"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
        field(:table_id, :string, required?: true, example: "tblXXXXXXXXXXXX")
        field(:record_ids, {:array, :string}, required?: true)
      end

      output do
        field(:records, {:array, :map})
      end
    end
  end
end
