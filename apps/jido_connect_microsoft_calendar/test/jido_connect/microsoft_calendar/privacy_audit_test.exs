defmodule Jido.Connect.MicrosoftCalendar.PrivacyAuditTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts
  alias Jido.Connect.MicrosoftCalendar
  alias Jido.Connect.MicrosoftCalendar.Privacy

  test "classifies every Microsoft Calendar action privacy boundary" do
    spec = MicrosoftCalendar.integration()
    actions_by_id = Map.new(spec.actions, &{&1.id, &1})

    expected =
      MapSet.new([
        "microsoft.calendar.calendars.list",
        "microsoft.calendar.calendar.get",
        "microsoft.calendar.events.list",
        "microsoft.calendar.event.get",
        "microsoft.calendar.schedule.get",
        "microsoft.calendar.meeting_times.find",
        "microsoft.calendar.event.create",
        "microsoft.calendar.event.update",
        "microsoft.calendar.event.delete"
      ])

    assert MapSet.new(Map.keys(actions_by_id)) == expected

    # ── Read actions ───────────────────────────────────────────────────
    calendars_list = actions_by_id["microsoft.calendar.calendars.list"]
    assert calendars_list.data_classification == :personal_data
    assert calendars_list.risk == :read
    assert calendars_list.confirmation == :none

    calendar_get = actions_by_id["microsoft.calendar.calendar.get"]
    assert calendar_get.data_classification == :personal_data
    assert calendar_get.risk == :read
    assert calendar_get.confirmation == :none

    events_list = actions_by_id["microsoft.calendar.events.list"]
    assert events_list.data_classification == :personal_data
    assert events_list.risk == :read
    assert events_list.confirmation == :none

    event_get = actions_by_id["microsoft.calendar.event.get"]
    assert event_get.data_classification == :personal_data
    assert event_get.risk == :read
    assert event_get.confirmation == :none

    schedule_get = actions_by_id["microsoft.calendar.schedule.get"]
    assert schedule_get.data_classification == :personal_data
    assert schedule_get.risk == :read
    assert schedule_get.confirmation == :none

    meeting_times_find = actions_by_id["microsoft.calendar.meeting_times.find"]
    assert meeting_times_find.data_classification == :personal_data
    assert meeting_times_find.risk == :read
    assert meeting_times_find.confirmation == :none

    # ── Write / external_write actions ─────────────────────────────────
    event_create = actions_by_id["microsoft.calendar.event.create"]
    assert event_create.data_classification == :personal_data
    assert event_create.risk == :external_write
    assert event_create.confirmation == :required_for_ai

    event_update = actions_by_id["microsoft.calendar.event.update"]
    assert event_update.data_classification == :personal_data
    assert event_update.risk == :write
    assert event_update.confirmation == :required_for_ai

    # ── Destructive actions ────────────────────────────────────────────
    event_delete = actions_by_id["microsoft.calendar.event.delete"]
    assert event_delete.data_classification == :personal_data
    assert event_delete.risk == :destructive
    assert event_delete.confirmation == :always
  end

  test "privacy module lists calendar content and personal data fields" do
    content_fields = Privacy.calendar_content_fields()
    assert :subject in content_fields
    assert :body_preview in content_fields
    assert :organizer in content_fields
    assert :attendees in content_fields
    assert :location in content_fields
    assert :start in content_fields
    assert :end in content_fields

    personal_fields = Privacy.personal_data_fields()
    assert :display_name in personal_fields
    assert :address in personal_fields
    assert :owner in personal_fields
    assert :calendar_id in personal_fields
    assert :email in personal_fields
    assert :subject in personal_fields
    assert :body_preview in personal_fields
    assert :organizer in personal_fields
    assert :attendees in personal_fields
    assert :location in personal_fields
  end

  test "privacy module detects raw body keys" do
    assert Privacy.raw_body_key?("content")
    assert Privacy.raw_body_key?(:content)
    refute Privacy.raw_body_key?("content_type")
    refute Privacy.raw_body_key?("body_size")
    refute Privacy.raw_body_key?(:id)
  end

  test "every action has reviewed data classification, risk, and confirmation" do
    spec = MicrosoftCalendar.integration()

    known_classifications = MapSet.new([:personal_data])
    known_risks = MapSet.new([:read, :write, :external_write, :destructive])
    known_confirmations = MapSet.new([:none, :required_for_ai, :always])

    for action <- spec.actions do
      assert MapSet.member?(known_classifications, action.data_classification),
             "#{action.id} has unreviewed data_classification: #{inspect(action.data_classification)}"

      assert MapSet.member?(known_risks, action.risk),
             "#{action.id} has unreviewed risk: #{inspect(action.risk)}"

      assert MapSet.member?(known_confirmations, action.confirmation),
             "#{action.id} has unreviewed confirmation: #{inspect(action.confirmation)}"

      if action.risk == :external_write do
        refute action.confirmation == :none,
               "#{action.id} is external_write but has no confirmation requirement"
      end

      if action.risk == :destructive do
        assert action.confirmation == :always,
               "#{action.id} is destructive but confirmation is not :always"
      end
    end
  end

  test "naming and catalog conventions cover privacy metadata" do
    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftCalendar,
      id_prefix: "microsoft.calendar.",
      pack_id_prefix: "microsoft_calendar_",
      module_namespace: Jido.Connect.MicrosoftCalendar
    )
  end
end
