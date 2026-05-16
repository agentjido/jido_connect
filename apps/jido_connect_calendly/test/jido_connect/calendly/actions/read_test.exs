defmodule Jido.Connect.Calendly.Actions.ReadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly

  @read_fragment Jido.Connect.Calendly.Actions.Read

  test "is a valid Spark DSL fragment" do
    assert {:module, @read_fragment} = Code.ensure_loaded(@read_fragment)
    assert @read_fragment.extensions() == [Jido.Connect.Dsl.Extension]
    assert @read_fragment.opts() == [of: Jido.Connect]
    assert %{extensions: [Jido.Connect.Dsl.Extension]} = @read_fragment.persisted()
    assert is_map(@read_fragment.spark_dsl_config())

    assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
             @read_fragment.validate_sections()
  end

  test "declares six read actions for event types, scheduled events, and invitees" do
    spec = Calendly.integration()

    action_ids = Enum.map(spec.actions, & &1.id)

    assert "calendly.event_types.list" in action_ids
    assert "calendly.event_types.get" in action_ids
    assert "calendly.scheduled_events.list" in action_ids
    assert "calendly.scheduled_events.get" in action_ids
    assert "calendly.invitees.list" in action_ids
    assert "calendly.invitees.get" in action_ids
  end

  @read_action_ids [
    "calendly.event_types.list",
    "calendly.event_types.get",
    "calendly.scheduled_events.list",
    "calendly.scheduled_events.get",
    "calendly.invitees.list",
    "calendly.invitees.get"
  ]

  defp read_actions(spec) do
    Enum.filter(spec.actions, &(&1.id in @read_action_ids))
  end

  test "all read actions have verb :get or :list" do
    spec = Calendly.integration()

    for action <- read_actions(spec) do
      assert action.verb in [:get, :list]
    end
  end

  test "all read actions have scope resolver" do
    spec = Calendly.integration()

    for action <- read_actions(spec) do
      assert action.scope_resolver == Jido.Connect.Calendly.ScopeResolver
    end
  end

  test "all read actions use personal_access_token auth profile" do
    spec = Calendly.integration()

    for action <- read_actions(spec) do
      assert action.auth_profile == :personal_access_token
    end
  end

  test "get actions have required uri input" do
    spec = Calendly.integration()

    for id <- [
          "calendly.event_types.get",
          "calendly.scheduled_events.get"
        ] do
      action = Enum.find(spec.actions, &(&1.id == id))
      uri_field = Enum.find(action.input, &(&1.name == :uri))
      assert uri_field.required? == true
    end
  end

  test "invitee get action has required event_uri and uri inputs" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.invitees.get"))

    event_uri_field = Enum.find(action.input, &(&1.name == :event_uri))
    assert event_uri_field.required? == true

    uri_field = Enum.find(action.input, &(&1.name == :uri))
    assert uri_field.required? == true
  end

  test "invitee list action has required event_uri input" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.invitees.list"))
    event_uri_field = Enum.find(action.input, &(&1.name == :event_uri))
    assert event_uri_field.required? == true
  end

  test "list actions default count to 20" do
    spec = Calendly.integration()

    for id <- [
          "calendly.event_types.list",
          "calendly.scheduled_events.list",
          "calendly.invitees.list"
        ] do
      action = Enum.find(spec.actions, &(&1.id == id))
      count_field = Enum.find(action.input, &(&1.name == :count))
      assert count_field.default == 20
    end
  end

  test "scheduled events list action supports date filters" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.scheduled_events.list"))
    field_names = Enum.map(action.input, & &1.name)
    assert :min_start_time in field_names
    assert :max_start_time in field_names
    assert :status in field_names
  end

  test "all read actions are non-mutating" do
    spec = Calendly.integration()

    for action <- read_actions(spec) do
      assert action.mutation? == false
    end
  end

  test "all read actions return normalized output fields" do
    spec = Calendly.integration()

    for action <- read_actions(spec) do
      output_names = Enum.map(action.output, & &1.name)

      case action.verb do
        :list ->
          assert :pagination in output_names

        :get ->
          assert length(output_names) >= 1
      end
    end
  end
end
