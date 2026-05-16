defmodule Jido.Connect.HubSpot.Actions.WriteTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot

  @write_fragment Jido.Connect.HubSpot.Actions.Write

  test "is a valid Spark DSL fragment" do
    assert {:module, @write_fragment} = Code.ensure_loaded(@write_fragment)
    assert @write_fragment.extensions() == [Jido.Connect.Dsl.Extension]
    assert @write_fragment.opts() == [of: Jido.Connect]
    assert %{extensions: [Jido.Connect.Dsl.Extension]} = @write_fragment.persisted()
    assert is_map(@write_fragment.spark_dsl_config())

    assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
             @write_fragment.validate_sections()
  end

  test "declares five write actions for contacts, deals, and notes" do
    spec = HubSpot.integration()

    action_ids = Enum.map(spec.actions, & &1.id)

    assert "hubspot.contacts.contact.create" in action_ids
    assert "hubspot.contacts.contact.update" in action_ids
    assert "hubspot.deals.deal.create" in action_ids
    assert "hubspot.deals.deal.update" in action_ids
    assert "hubspot.notes.note.create" in action_ids
  end

  test "all write actions have verb :create or :update" do
    spec = HubSpot.integration()

    write_ids = [
      "hubspot.contacts.contact.create",
      "hubspot.contacts.contact.update",
      "hubspot.deals.deal.create",
      "hubspot.deals.deal.update",
      "hubspot.notes.note.create"
    ]

    for id <- write_ids do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.verb in [:create, :update], "Action #{id} has verb #{inspect(action.verb)}"
    end
  end

  test "all write actions are mutations with :write risk" do
    spec = HubSpot.integration()

    write_ids = [
      "hubspot.contacts.contact.create",
      "hubspot.contacts.contact.update",
      "hubspot.deals.deal.create",
      "hubspot.deals.deal.update",
      "hubspot.notes.note.create"
    ]

    for id <- write_ids do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.mutation? == true, "Action #{id} should be a mutation"
      assert action.risk == :write, "Action #{id} should have :write risk"
    end
  end

  test "all write actions require confirmation for AI" do
    spec = HubSpot.integration()

    write_ids = [
      "hubspot.contacts.contact.create",
      "hubspot.contacts.contact.update",
      "hubspot.deals.deal.create",
      "hubspot.deals.deal.update",
      "hubspot.notes.note.create"
    ]

    for id <- write_ids do
      action = Enum.find(spec.actions, &(&1.id == id))

      assert action.confirmation == :required_for_ai,
             "Action #{id} should require confirmation for AI"
    end
  end

  test "all write actions have scope resolver" do
    spec = HubSpot.integration()

    write_ids = [
      "hubspot.contacts.contact.create",
      "hubspot.contacts.contact.update",
      "hubspot.deals.deal.create",
      "hubspot.deals.deal.update",
      "hubspot.notes.note.create"
    ]

    for id <- write_ids do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.scope_resolver == Jido.Connect.HubSpot.ScopeResolver
    end
  end

  test "all write actions use private_app_token auth profile" do
    spec = HubSpot.integration()

    write_ids = [
      "hubspot.contacts.contact.create",
      "hubspot.contacts.contact.update",
      "hubspot.deals.deal.create",
      "hubspot.deals.deal.update",
      "hubspot.notes.note.create"
    ]

    for id <- write_ids do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.auth_profile == :private_app_token
    end
  end

  test "contact write actions have correct write scopes" do
    spec = HubSpot.integration()

    for id <- ["hubspot.contacts.contact.create", "hubspot.contacts.contact.update"] do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.scopes == ["crm.objects.contacts.write"]
    end
  end

  test "deal write actions have correct write scopes" do
    spec = HubSpot.integration()

    for id <- ["hubspot.deals.deal.create", "hubspot.deals.deal.update"] do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.scopes == ["crm.objects.deals.write"]
    end
  end

  test "create note action has both contacts and deals write scopes" do
    spec = HubSpot.integration()

    action = Enum.find(spec.actions, &(&1.id == "hubspot.notes.note.create"))
    assert "crm.objects.contacts.write" in action.scopes
    assert "crm.objects.deals.write" in action.scopes
  end

  test "update actions require their respective ID field" do
    spec = HubSpot.integration()

    update_contact = Enum.find(spec.actions, &(&1.id == "hubspot.contacts.contact.update"))
    contact_id_field = Enum.find(update_contact.input, &(&1.name == :contact_id))
    assert contact_id_field.required? == true

    update_deal = Enum.find(spec.actions, &(&1.id == "hubspot.deals.deal.update"))
    deal_id_field = Enum.find(update_deal.input, &(&1.name == :deal_id))
    assert deal_id_field.required? == true
  end

  test "create note action requires body field" do
    spec = HubSpot.integration()

    action = Enum.find(spec.actions, &(&1.id == "hubspot.notes.note.create"))
    body_field = Enum.find(action.input, &(&1.name == :body))
    assert body_field.required? == true
  end

  test "create note action has association ID arrays" do
    spec = HubSpot.integration()

    action = Enum.find(spec.actions, &(&1.id == "hubspot.notes.note.create"))
    field_names = Enum.map(action.input, & &1.name)

    assert :contact_ids in field_names
    assert :company_ids in field_names
    assert :deal_ids in field_names
    assert :ticket_ids in field_names
  end
end
