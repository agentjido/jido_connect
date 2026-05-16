defmodule Jido.Connect.Salesforce.Actions.ReadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce

  describe "contact read actions" do
    test "read fragment declares get_contact action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.contacts.contact.get" in action_ids
      assert "salesforce.contacts.contact.list" in action_ids
    end

    test "get_contact action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.get"))

      assert action.resource == :contact
      assert action.verb == :get
      assert action.risk == :read
      assert action.data_classification == :personal_data
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.GetContact
    end

    test "list_contacts action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.list"))

      assert action.resource == :contact
      assert action.verb == :list
      assert action.risk == :read
      assert action.data_classification == :personal_data
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.ListContacts
    end
  end

  describe "generic SObject query/read actions" do
    test "read fragment declares query action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.query" in action_ids
    end

    test "query action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.query"))

      assert action.resource == :sobject
      assert action.verb == :list
      assert action.risk == :read
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.Query
    end

    test "read fragment declares get_record action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.record.get" in action_ids
    end

    test "get_record action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.record.get"))

      assert action.resource == :sobject
      assert action.verb == :get
      assert action.risk == :read
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.GetRecord
    end

    test "read fragment declares describe_object action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.object.describe" in action_ids
    end

    test "describe_object action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.object.describe"))

      assert action.resource == :sobject
      assert action.verb == :read
      assert action.risk == :read
      assert action.data_classification == :tool_metadata
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.DescribeObject
    end

    test "read fragment declares list_recent action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.record.list_recent" in action_ids
    end

    test "list_recent action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.record.list_recent"))

      assert action.resource == :sobject
      assert action.verb == :list
      assert action.risk == :read
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.ListRecent
    end

    test "read fragment declares query_more action" do
      spec = Salesforce.integration()
      action_ids = Enum.map(spec.actions, & &1.id)

      assert "salesforce.crm.query_more" in action_ids
    end

    test "query_more action has correct metadata" do
      spec = Salesforce.integration()
      action = Enum.find(spec.actions, &(&1.id == "salesforce.crm.query_more"))

      assert action.resource == :sobject
      assert action.verb == :list
      assert action.risk == :read
      assert action.data_classification == :workspace_content
      assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.QueryMore
    end
  end
end
