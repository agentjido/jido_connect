defmodule Jido.Connect.Jira.Webhook.IssueSignalTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.{CapturedDelivery, Webhook}

  # The payloads are administrator deliveries of one capture run on a test
  # issue, 2026-10-30, sanitized into test/fixtures/jira/captured. A payload
  # that no capture covers is derived from one of them by changing exactly
  # one part; the test names that part and why.

  describe "assignment" do
    test "a reassignment keeps issue identity, event name, actor and both accounts" do
      assert {:ok, signal} = normalize("assignee_changed")

      assert %{
               issue_id: "46154",
               issue_key: "JCL-59",
               issue_event_type_name: "issue_updated",
               actor_id: "account-1",
               actor_name: "Person 1",
               assigned: true,
               assignee_id: "account-2",
               assignee_name: "Person 2"
             } = signal

      assert signal.changelog == %{
               id: "283377",
               items: [
                 %{
                   field: "assignee",
                   field_id: "assignee",
                   field_type: "jira",
                   from: "account-1",
                   from_string: "Person 1",
                   to: "account-2",
                   to_string: "Person 2"
                 }
               ]
             }
    end

    test "an unassignment keeps the explicit null target and reports no assignee" do
      assert {:ok, signal} = normalize("assignee_cleared")

      assert %{issue_id: "46154", issue_event_type_name: "issue_updated", assigned: false} =
               signal

      refute Map.has_key?(signal, :assignee_id)
      refute Map.has_key?(signal, :assignee_name)

      # The sanitizer replaced the former assignee, who appears only in this
      # item, with field placeholders; see the live smoke test.
      assert %{
               id: "283378",
               items: [
                 %{
                   field_id: "assignee",
                   from: "from-1",
                   from_string: "Person 1",
                   to: nil,
                   to_string: nil
                 }
               ]
             } = signal.changelog
    end

    test "an assignment of an unassigned issue keeps the explicit null source" do
      assert {:ok, signal} = normalize("assignee_set")

      assert %{assigned: true, assignee_id: "account-1", actor_id: "account-1"} = signal

      assert %{
               id: "283379",
               items: [
                 %{
                   field_id: "assignee",
                   from: nil,
                   from_string: nil,
                   to: "account-1",
                   to_string: "Person 1"
                 }
               ]
             } = signal.changelog
    end

    test "an unrelated update carries no assignee item" do
      for name <- ~w(status_changed duedate_moved duedate_cleared) do
        assert {:ok, signal} = normalize(name)
        assert %{assigned: true, assignee_id: "account-1"} = signal
        refute Enum.any?(signal.changelog.items, &(&1.field_id == "assignee"))
      end
    end
  end

  describe "explicit presence" do
    test "an assignee sent as null and an assignee left out yield distinguishable signals" do
      assert {:ok, unassigned} = normalize("assignee_cleared")

      # Derived: the same delivery without `assignee` in the issue fields, as
      # a delivery whose fields leave the assignee out would arrive.
      payload =
        update_in(payload!("assignee_cleared"), ["issue", "fields"], &Map.delete(&1, "assignee"))

      assert {:ok, left_out} = Webhook.normalize_event(payload)

      assert unassigned.assigned == false
      refute Map.has_key?(left_out, :assigned)
      refute Map.has_key?(left_out, :assignee_id)
      assert Map.delete(unassigned, :assigned) == left_out
    end

    test "an item with a null target and an item without a target yield distinguishable signals" do
      assert {:ok, cleared} = normalize("duedate_cleared")

      # Derived: the same changelog item without its `to` key.
      payload =
        update_in(payload!("duedate_cleared"), ["changelog", "items"], fn [item] ->
          [Map.delete(item, "to")]
        end)

      assert {:ok, without_to} = Webhook.normalize_event(payload)

      assert [%{to: nil, to_string: nil} = with_null] = cleared.changelog.items
      assert [without] = without_to.changelog.items
      refute Map.has_key?(without, :to)
      assert without == Map.delete(with_null, :to)
    end

    test "an item with an empty source text and an item without one yield distinguishable signals" do
      # Derived: the captured due-date clear once with `fromString` set to ""
      # and once without `fromString`. No capture holds an empty value, but
      # a compacting normalizer would drop "" and merge both cases.
      empty =
        update_in(payload!("duedate_cleared"), ["changelog", "items"], fn [item] ->
          [%{item | "fromString" => ""}]
        end)

      left_out =
        update_in(payload!("duedate_cleared"), ["changelog", "items"], fn [item] ->
          [Map.delete(item, "fromString")]
        end)

      assert {:ok, %{changelog: %{items: [with_empty]}}} = Webhook.normalize_event(empty)
      assert {:ok, %{changelog: %{items: [without]}}} = Webhook.normalize_event(left_out)

      assert with_empty.from_string == ""
      refute Map.has_key?(without, :from_string)
      assert without == Map.delete(with_empty, :from_string)
    end
  end

  describe "absent parts" do
    # Every captured issue delivery carries `changelog`, `user`,
    # `issue.fields` and `timestamp`, as Jira documents them. The normalizer
    # reads a missing part as absent rather than malformed, so each derived
    # payload leaves out exactly one part of the captured status change and
    # loses only the signal fields read from that part.
    @fields_keys ~w(project_key project_name summary issue_type_name status_name priority_name
                    reporter_id reporter_name created_at updated_at assigned assignee_id
                    assignee_name)a

    test "a delivery without changelog, user, fields or timestamp keeps every other field" do
      assert {:ok, baseline} = normalize("status_changed")

      rows = [
        {"changelog", &Map.delete(&1, "changelog"), [:changelog]},
        {"user", &Map.delete(&1, "user"), [:actor_id, :actor_name]},
        {"issue.fields", &update_in(&1, ["issue"], fn i -> Map.delete(i, "fields") end),
         @fields_keys},
        {"timestamp", &Map.delete(&1, "timestamp"), [:timestamp]}
      ]

      for {part, leave_out, dropped} <- rows do
        assert Enum.all?(dropped, &Map.has_key?(baseline, &1)), part

        assert {:ok, signal} =
                 payload!("status_changed") |> leave_out.() |> Webhook.normalize_event()

        assert signal == Map.drop(baseline, dropped), part
      end
    end

    test "a changelog without items keeps its id" do
      assert {:ok, baseline} = normalize("status_changed")

      # Derived: the captured status change without `changelog.items`.
      payload = update_in(payload!("status_changed"), ["changelog"], &Map.delete(&1, "items"))

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal == %{baseline | changelog: %{id: baseline.changelog.id}}
    end
  end

  describe "status and due date" do
    test "a status change keeps status IDs and names under Jira's generic event name" do
      assert {:ok, signal} = normalize("status_changed")

      assert %{issue_event_type_name: "issue_generic", status_name: "In Progress"} = signal

      assert signal.changelog.items == [
               %{
                 field: "status",
                 field_id: "status",
                 field_type: "jira",
                 from: "10916",
                 from_string: "Backlog",
                 to: "3",
                 to_string: "In Progress"
               }
             ]
    end

    test "a due-date move keeps date-only values" do
      assert {:ok, signal} = normalize("duedate_moved")

      assert signal.issue_event_type_name == "issue_updated"

      assert signal.changelog.items == [
               %{
                 field: "duedate",
                 field_id: "duedate",
                 field_type: "jira",
                 from: "2026-12-01",
                 from_string: "2026-12-01 00:00:00.0",
                 to: "2026-12-15",
                 to_string: "2026-12-15 00:00:00.0"
               }
             ]
    end

    test "a due-date clear keeps the explicit null target" do
      assert {:ok, signal} = normalize("duedate_cleared")

      assert [%{field_id: "duedate", from: "2026-12-15", to: nil, to_string: nil}] =
               signal.changelog.items
    end

    test "a due-date set keeps the explicit null source" do
      # Derived: the captured move with `from` and `fromString` set to null.
      # The capture run created the issue with a due date, so no delivery of
      # a first setting is recorded. The null source follows the captured
      # first assignment, not an observed due-date delivery.
      payload =
        update_in(payload!("duedate_moved"), ["changelog", "items"], fn [item] ->
          [%{item | "from" => nil, "fromString" => nil}]
        end)

      assert {:ok, signal} = Webhook.normalize_event(payload)

      assert [%{field_id: "duedate", from: nil, from_string: nil, to: "2026-12-15"}] =
               signal.changelog.items
    end

    test "both items of a mixed status and due-date update survive" do
      # Derived: the captured status change with the item of the captured
      # due-date move appended. The capture run changed status and due date
      # in separate edits; no delivery of a transition that also sets the
      # due date is recorded.
      [due_date_item] = get_in(payload!("duedate_moved"), ["changelog", "items"])

      payload =
        update_in(payload!("status_changed"), ["changelog", "items"], &(&1 ++ [due_date_item]))

      assert {:ok, signal} = Webhook.normalize_event(payload)

      assert [
               %{field_id: "status", from: "10916", to: "3"},
               %{field_id: "duedate", from: "2026-12-01", to: "2026-12-15"}
             ] = signal.changelog.items
    end
  end

  describe "matched webhook IDs" do
    test "administrator deliveries name none, so the field is absent" do
      for name <- issue_captures() do
        assert {:ok, signal} = normalize(name)
        refute Map.has_key?(signal, :matched_webhook_ids)
        refute Map.has_key?(signal, :webhook_id)
      end
    end

    test "matchedWebhookIds become strings" do
      # Derived: the captured status change with the numeric
      # `matchedWebhookIds` of an app-registered webhook delivery.
      payload = Map.put(payload!("status_changed"), "matchedWebhookIds", [10_001, 10_002])

      assert {:ok, %{matched_webhook_ids: ["10001", "10002"]}} = Webhook.normalize_event(payload)
    end
  end

  describe "timestamps" do
    test "every captured issue delivery yields an ISO 8601 string" do
      expected = %{
        "issue_created" => "2026-10-30T19:34:47.074Z",
        "assignee_changed" => "2026-10-30T19:34:49.566Z",
        "assignee_cleared" => "2026-10-30T19:34:52.090Z",
        "assignee_set" => "2026-10-30T19:34:54.736Z",
        "status_changed" => "2026-10-30T19:34:57.477Z",
        "duedate_moved" => "2026-10-30T19:35:00.072Z",
        "duedate_cleared" => "2026-10-30T19:35:02.520Z"
      }

      assert Map.keys(expected) |> Enum.sort() == issue_captures()

      for {name, timestamp} <- expected do
        assert {:ok, %{timestamp: ^timestamp}} = normalize(name)
      end
    end
  end

  describe "declared signal" do
    test "jira.issue.changed declares every field the captured and derived deliveries yield" do
      schema = trigger("jira.issue.changed").signal_schema

      # Derived: the captured status change with a `matchedWebhookIds` list.
      matched = Map.put(payload!("status_changed"), "matchedWebhookIds", [1])

      for payload <- [matched | Enum.map(issue_captures(), &payload!/1)] do
        assert {:ok, signal} = Webhook.normalize_event(payload)
        assert {:ok, ^signal} = Zoi.parse(schema, signal)
      end
    end

    test "jira.issue.changed describes the presence of assigned and matched_webhook_ids" do
      fields = Map.new(trigger("jira.issue.changed").signal, &{&1.name, &1})

      assert %{type: :boolean, description: assigned} = fields.assigned
      assert assigned =~ "null"

      assert %{type: {:array, :string}, description: matched} = fields.matched_webhook_ids
      assert matched =~ "Administrator webhooks"

      assert %{type: :string} = fields.actor_id
      assert %{type: :string} = fields.actor_name
      refute Map.has_key?(fields, :webhook_id)
    end

    test "jira.issue.changed maps no change to an event name and points to changelog items" do
      fields = Map.new(trigger("jira.issue.changed").signal, &{&1.name, &1})

      # Jira names the event that fired, which depends on the operation and
      # the workflow, so the catalog must not promise a name per change.
      assert %{type: :string, description: description} = fields.issue_event_type_name
      assert description =~ "changelog items"
      refute description =~ "issue_generic"
      refute description =~ "issue_updated"
    end
  end

  defp normalize(name), do: name |> payload!() |> Webhook.normalize_event()

  defp payload!(name), do: CapturedDelivery.payload!(name)

  defp issue_captures,
    do: Enum.reject(CapturedDelivery.names(), &String.starts_with?(&1, "comment_"))

  defp trigger(id), do: Enum.find(Jido.Connect.Jira.integration().triggers, &(&1.id == id))
end
