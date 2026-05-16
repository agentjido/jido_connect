defmodule Jido.Connect.HubSpot.Actions.ReadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot

  @read_fragment Jido.Connect.HubSpot.Actions.Read

  test "is a valid Spark DSL fragment" do
    assert {:module, @read_fragment} = Code.ensure_loaded(@read_fragment)
    assert @read_fragment.extensions() == [Jido.Connect.Dsl.Extension]
    assert @read_fragment.opts() == [of: Jido.Connect]
    assert %{extensions: [Jido.Connect.Dsl.Extension]} = @read_fragment.persisted()
    assert is_map(@read_fragment.spark_dsl_config())

    assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
             @read_fragment.validate_sections()
  end

  test "declares nine read actions for contacts, companies, and deals" do
    spec = HubSpot.integration()

    action_ids = Enum.map(spec.actions, & &1.id)

    assert "hubspot.contacts.contact.get" in action_ids
    assert "hubspot.contacts.contact.list" in action_ids
    assert "hubspot.contacts.contact.search" in action_ids
    assert "hubspot.companies.company.get" in action_ids
    assert "hubspot.companies.company.list" in action_ids
    assert "hubspot.companies.company.search" in action_ids
    assert "hubspot.deals.deal.get" in action_ids
    assert "hubspot.deals.deal.list" in action_ids
    assert "hubspot.deals.deal.search" in action_ids
  end

  test "all read actions have verb :get or :list or :search" do
    spec = HubSpot.integration()

    for action <- spec.actions do
      assert action.verb in [:get, :list, :search]
    end
  end

  test "all read actions have scope resolver" do
    spec = HubSpot.integration()

    for action <- spec.actions do
      assert action.scope_resolver == Jido.Connect.HubSpot.ScopeResolver
    end
  end

  test "all read actions use private_app_token auth profile" do
    spec = HubSpot.integration()

    for action <- spec.actions do
      assert action.auth_profile == :private_app_token
    end
  end

  test "contact get action has required contact_id input" do
    spec = HubSpot.integration()

    get_action = Enum.find(spec.actions, &(&1.id == "hubspot.contacts.contact.get"))
    id_field = Enum.find(get_action.input, &(&1.name == :contact_id))
    assert id_field.required? == true
  end

  test "list actions default archived to false" do
    spec = HubSpot.integration()

    for id <- [
          "hubspot.contacts.contact.list",
          "hubspot.companies.company.list",
          "hubspot.deals.deal.list"
        ] do
      action = Enum.find(spec.actions, &(&1.id == id))
      archived_field = Enum.find(action.input, &(&1.name == :archived))
      assert archived_field.default == false
    end
  end

  test "search actions accept query and filter_groups" do
    spec = HubSpot.integration()

    search_action = Enum.find(spec.actions, &(&1.id == "hubspot.contacts.contact.search"))

    field_names = Enum.map(search_action.input, & &1.name)
    assert :query in field_names
    assert :filter_groups in field_names
  end
end
