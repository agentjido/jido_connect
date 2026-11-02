defmodule Jido.Connect.Jira.Webhook.MalformedPayloadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Jira.{CapturedDelivery, Webhook}

  # Each row derives a malformed payload from a captured administrator
  # delivery by changing exactly one part, then expects the error reason and
  # the complete error details. The details name the event type and the
  # payload path only, never the changed value.

  defp issue_rows do
    [
      {"issue left out", &Map.delete(&1, "issue"), "issue"},
      {"issue not an object", &Map.put(&1, "issue", "JCL-59"), "issue"},
      {"issue id left out", &delete_in(&1, ["issue"], "id"), "issue.id"},
      {"issue id a number", &put_in(&1, ["issue", "id"], 46_154), "issue.id"},
      {"issue id empty", &put_in(&1, ["issue", "id"], ""), "issue.id"},
      {"fields not an object", &put_in(&1, ["issue", "fields"], ["summary"]), "issue.fields"},
      {"user not an object", &Map.put(&1, "user", "account-1"), "user"},
      {"changelog not an object", &Map.put(&1, "changelog", []), "changelog"},
      {"changelog items not a list", &put_in(&1, ["changelog", "items"], %{}), "changelog.items"},
      {"changelog item not an object", &put_in(&1, ["changelog", "items"], ["status"]),
       "changelog.items"},
      {"changelog item null", &put_in(&1, ["changelog", "items"], [nil]), "changelog.items"},
      {"assignee not an object", &put_in(&1, ["issue", "fields", "assignee"], "account-1"),
       "issue.fields.assignee"},
      {"timestamp a word", &Map.put(&1, "timestamp", "yesterday"), "timestamp"},
      {"timestamp digits with a suffix", &Map.put(&1, "timestamp", "1793388897477ms"),
       "timestamp"},
      {"timestamp digits with a minus sign", &Map.put(&1, "timestamp", "-1793388897477"),
       "timestamp"},
      {"timestamp digits with a plus sign", &Map.put(&1, "timestamp", "+1793388897477"),
       "timestamp"},
      {"timestamp a float", &Map.put(&1, "timestamp", 1_793_388_897_477.5), "timestamp"},
      {"timestamp beyond the DateTime range", &Map.put(&1, "timestamp", 10 ** 20), "timestamp"},
      {"matchedWebhookIds not a list", &Map.put(&1, "matchedWebhookIds", "10001"),
       "matchedWebhookIds"},
      {"matchedWebhookIds with an object", &Map.put(&1, "matchedWebhookIds", [%{"id" => 1}]),
       "matchedWebhookIds"}
    ]
  end

  defp comment_rows do
    [
      {"comment left out", &Map.delete(&1, "comment"), "comment"},
      {"comment not an object", &Map.put(&1, "comment", "42727"), "comment"},
      {"comment id left out", &delete_in(&1, ["comment"], "id"), "comment.id"},
      {"comment id a number", &put_in(&1, ["comment", "id"], 42_727), "comment.id"},
      {"issue left out", &Map.delete(&1, "issue"), "issue"},
      {"issue id left out", &delete_in(&1, ["issue"], "id"), "issue.id"},
      {"author not an object", &put_in(&1, ["comment", "author"], "account-1"), "comment.author"},
      {"updateAuthor not an object", &put_in(&1, ["comment", "updateAuthor"], ["account-1"]),
       "comment.updateAuthor"},
      {"timestamp a word", &Map.put(&1, "timestamp", "yesterday"), "timestamp"},
      {"matchedWebhookIds not a list", &Map.put(&1, "matchedWebhookIds", 10_001),
       "matchedWebhookIds"}
    ]
  end

  test "malformed issue deliveries return :invalid_webhook_event naming only the path" do
    for {label, change, path} <- issue_rows() do
      payload = change.(CapturedDelivery.payload!("status_changed"))

      assert {:error, %ProviderError{reason: :invalid_webhook_event, details: details}} =
               Webhook.normalize_event(payload),
             label

      assert details == %{event_type: "jira:issue_updated", field: path}, label
    end
  end

  test "malformed comment deliveries return :invalid_webhook_event naming only the path" do
    for {label, change, path} <- comment_rows() do
      payload = change.(CapturedDelivery.payload!("comment_updated"))

      assert {:error, %ProviderError{reason: :invalid_webhook_event, details: details}} =
               Webhook.normalize_event(payload),
             label

      assert details == %{event_type: "comment_updated", field: path}, label
    end
  end

  test "a comment body that is neither a string nor ADF names the path and the ADF reason" do
    for body <- [%{}, 42, ["Capture comment"]] do
      payload = put_in(CapturedDelivery.payload!("comment_created"), ["comment", "body"], body)

      assert {:error, %ProviderError{reason: :invalid_webhook_event, details: details}} =
               Webhook.normalize_event(payload)

      assert %{event_type: "comment_created", field: "comment.body", adf_reason: reason} =
               details

      assert is_atom(reason)
      assert map_size(details) == 3
    end
  end

  test "payloads without a usable event name return errors without details" do
    capture = CapturedDelivery.capture!("status_changed")
    payload = Jason.decode!(capture["body"])

    rows = [
      {"the undecoded body", capture["body"], :invalid_webhook_event},
      {"a list of events", [payload], :invalid_webhook_event},
      {"webhookEvent left out", Map.delete(payload, "webhookEvent"), :invalid_webhook_event},
      {"webhookEvent a list", Map.put(payload, "webhookEvent", ["jira:issue_updated"]),
       :invalid_webhook_event},
      {"another event name", Map.put(payload, "webhookEvent", "jira:worklog_created"),
       :unsupported_webhook_event}
    ]

    for {label, payload, reason} <- rows do
      assert {:error, %ProviderError{reason: ^reason, details: details}} =
               Webhook.normalize_event(payload),
             label

      assert details == %{}, label
    end
  end

  test "malformed values that the signal only reads are left out without raising" do
    assert {:ok, baseline} = Webhook.normalize_event(CapturedDelivery.payload!("status_changed"))

    # Derived: the captured status change with one of project, status or
    # reporter replaced by a value that is not an object.
    rows = [
      {"project", "JCL", [:project_key, :project_name]},
      {"status", 3, [:status_name]},
      {"reporter", ["account-1"], [:reporter_id, :reporter_name]}
    ]

    for {field, value, dropped} <- rows do
      payload =
        put_in(CapturedDelivery.payload!("status_changed"), ["issue", "fields", field], value)

      assert Enum.all?(dropped, &Map.has_key?(baseline, &1)), field
      assert {:ok, signal} = Webhook.normalize_event(payload), field
      assert signal == Map.drop(baseline, dropped), field
    end
  end

  test "normalize_events/1 stops at the first malformed event" do
    created = CapturedDelivery.payload!("issue_created")
    malformed = Map.delete(CapturedDelivery.payload!("comment_created"), "comment")

    assert {:error, %ProviderError{reason: :invalid_webhook_event, details: details}} =
             Webhook.normalize_events([created, malformed])

    assert details == %{event_type: "comment_created", field: "comment"}
  end

  defp delete_in(payload, path, key), do: update_in(payload, path, &Map.delete(&1, key))
end
