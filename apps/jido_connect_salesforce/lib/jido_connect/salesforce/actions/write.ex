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

    action :update_contact do
      id("salesforce.contacts.contact.update")
      resource(:contact)
      verb(:update)
      data_classification(:personal_data)
      label("Update contact")
      description("Update an existing Salesforce contact by ID.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.UpdateContact)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:contact_id, :string, required?: true, example: "0035g00000ABCdE")
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

    # -----------------------------------------------------------------------
    # Lead write actions
    # -----------------------------------------------------------------------

    action :create_lead do
      id("salesforce.crm.lead.create")
      resource(:lead)
      verb(:create)
      data_classification(:personal_data)
      label("Create lead")
      description("Create a new Salesforce lead.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.CreateLead)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:first_name, :string, example: "Alex")
        field(:last_name, :string, example: "Chen")
        field(:email, :string, example: "alex@example.com")
        field(:phone, :string, example: "+1-555-0202")
        field(:company, :string, example: "Acme Corp")
        field(:title, :string, example: "VP Engineering")
        field(:status, :string, example: "Open - Not Contacted")
        field(:source, :string, example: "Web")
        field(:owner_id, :string, example: "0055g00000ABCdE")
        field(:properties, :map, default: %{})
      end

      output do
        field(:lead_id, :string)
        field(:success, :boolean)
      end
    end

    action :update_lead do
      id("salesforce.crm.lead.update")
      resource(:lead)
      verb(:update)
      data_classification(:personal_data)
      label("Update lead")
      description("Update an existing Salesforce lead by ID.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.UpdateLead)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:lead_id, :string, required?: true, example: "00Q5g00000ABCdE")
        field(:first_name, :string, example: "Alex")
        field(:last_name, :string, example: "Chen")
        field(:email, :string, example: "alex@example.com")
        field(:phone, :string, example: "+1-555-0202")
        field(:company, :string, example: "Acme Corp")
        field(:title, :string, example: "VP Engineering")
        field(:status, :string, example: "Working - Contacted")
        field(:source, :string, example: "Web")
        field(:owner_id, :string, example: "0055g00000ABCdE")
        field(:properties, :map, default: %{})
      end

      output do
        field(:lead_id, :string)
        field(:success, :boolean)
      end
    end

    # -----------------------------------------------------------------------
    # Task write actions
    # -----------------------------------------------------------------------

    action :create_task do
      id("salesforce.crm.task.create")
      resource(:task)
      verb(:create)
      data_classification(:workspace_content)
      label("Create task")
      description("Create a new Salesforce task.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.CreateTask)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:subject, :string, example: "Follow up with lead")
        field(:status, :string, example: "Not Started")
        field(:priority, :string, example: "Normal")
        field(:description, :string, example: "Call to discuss pricing")
        field(:who_id, :string, example: "0035g00000ABCdE")
        field(:what_id, :string, example: "0015g00000XYZaA")
        field(:owner_id, :string, example: "0055g00000ABCdE")
        field(:activity_date, :string, example: "2026-06-01")
        field(:properties, :map, default: %{})
      end

      output do
        field(:task_id, :string)
        field(:success, :boolean)
      end
    end

    action :update_task do
      id("salesforce.crm.task.update")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Update task")
      description("Update an existing Salesforce task by ID.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.UpdateTask)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:task_id, :string, required?: true, example: "00T5g00000ABCdE")
        field(:subject, :string, example: "Follow up with lead")
        field(:status, :string, example: "Completed")
        field(:priority, :string, example: "Normal")
        field(:description, :string, example: "Call to discuss pricing")
        field(:who_id, :string, example: "0035g00000ABCdE")
        field(:what_id, :string, example: "0015g00000XYZaA")
        field(:owner_id, :string, example: "0055g00000ABCdE")
        field(:activity_date, :string, example: "2026-06-01")
        field(:properties, :map, default: %{})
      end

      output do
        field(:task_id, :string)
        field(:success, :boolean)
      end
    end

    # -----------------------------------------------------------------------
    # Generic SObject write actions
    # -----------------------------------------------------------------------

    action :create_record do
      id("salesforce.crm.record.create")
      resource(:sobject)
      verb(:create)
      data_classification(:workspace_content)
      label("Create record")
      description("Create a new Salesforce record for any SObject type.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.CreateRecord)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:sobject_type, :string, required?: true, example: "Account")
        field(:fields, :map, default: %{})
        field(:properties, :map, default: %{})
      end

      output do
        field(:record_id, :string)
        field(:success, :boolean)
      end
    end

    action :update_record do
      id("salesforce.crm.record.update")
      resource(:sobject)
      verb(:update)
      data_classification(:workspace_content)
      label("Update record")
      description("Update an existing Salesforce record by SObject type and ID.")
      handler(Jido.Connect.Salesforce.Handlers.Actions.UpdateRecord)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:oauth2_connected_app)
        scopes(["api"], resolver: @scope_resolver)
      end

      input do
        field(:sobject_type, :string, required?: true, example: "Account")
        field(:record_id, :string, required?: true, example: "0015g00000XYZaA")
        field(:fields, :map, default: %{})
        field(:properties, :map, default: %{})
      end

      output do
        field(:record_id, :string)
        field(:success, :boolean)
      end
    end
  end
end
