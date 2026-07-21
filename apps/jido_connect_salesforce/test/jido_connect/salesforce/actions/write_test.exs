defmodule Jido.Connect.Salesforce.Actions.WriteTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce

  describe "contact write actions" do
    test "write fragment declares create_contact action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.contacts.contact.create" in action_ids
    end

    test "create_contact action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.create"))

      assert action.resource == :contact
      assert action.verb == :create
      assert action.risk == :write
      assert action.data_classification == :personal_data
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.CreateContact
      assert action.confirmation == :required_for_ai
    end

    test "write fragment declares update_contact action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.contacts.contact.update" in action_ids
    end

    test "update_contact action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.update"))

      assert action.resource == :contact
      assert action.verb == :update
      assert action.risk == :write
      assert action.data_classification == :personal_data
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.UpdateContact
      assert action.confirmation == :required_for_ai
    end
  end

  describe "lead write actions" do
    test "write fragment declares create_lead action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.lead.create" in action_ids
    end

    test "create_lead action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.lead.create"))

      assert action.resource == :lead
      assert action.verb == :create
      assert action.risk == :write
      assert action.data_classification == :personal_data
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.CreateLead
      assert action.confirmation == :required_for_ai
    end

    test "write fragment declares update_lead action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.lead.update" in action_ids
    end

    test "update_lead action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.lead.update"))

      assert action.resource == :lead
      assert action.verb == :update
      assert action.risk == :write
      assert action.data_classification == :personal_data
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.UpdateLead
      assert action.confirmation == :required_for_ai
    end
  end

  describe "task write actions" do
    test "write fragment declares create_task action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.task.create" in action_ids
    end

    test "create_task action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.task.create"))

      assert action.resource == :task
      assert action.verb == :create
      assert action.risk == :write
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.CreateTask
      assert action.confirmation == :required_for_ai
    end

    test "write fragment declares update_task action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.task.update" in action_ids
    end

    test "update_task action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.task.update"))

      assert action.resource == :task
      assert action.verb == :update
      assert action.risk == :write
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.UpdateTask
      assert action.confirmation == :required_for_ai
    end
  end

  describe "generic SObject write actions" do
    test "write fragment declares create_record action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.record.create" in action_ids
    end

    test "create_record action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.record.create"))

      assert action.resource == :sobject
      assert action.verb == :create
      assert action.risk == :write
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.CreateRecord
      assert action.confirmation == :required_for_ai
    end

    test "write fragment declares update_record action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.record.update" in action_ids
    end

    test "update_record action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.record.update"))

      assert action.resource == :sobject
      assert action.verb == :update
      assert action.risk == :write
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.UpdateRecord
      assert action.confirmation == :required_for_ai
    end
  end
end
