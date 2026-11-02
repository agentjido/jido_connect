defmodule Jido.Connect.Jira.Webhook.CommentSignalTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.{CapturedDelivery, Webhook}
  alias Jido.Connect.TestSupport.LiveSmoke
  alias Jido.Connect.WebhookDelivery

  # The payloads are administrator deliveries of one capture run on a test
  # issue, 2026-10-30, sanitized into test/fixtures/jira/captured. A payload
  # that no capture covers is derived from one of them by changing exactly
  # one part; the test names that part and why.

  describe "comment events" do
    test "comment_created yields a creation with identities, author, actor and provider times" do
      assert {:ok, signal} = normalize("comment_created")

      assert signal == %{
               event_type: "comment_created",
               change_type: "created",
               actor_id: "account-1",
               actor_name: "Person 1",
               comment_id: "42727",
               comment_body: "Capture comment, first version.",
               comment_body_unsupported_nodes: [],
               comment_created_at: "2026-10-30T20:35:05.025+0100",
               comment_updated_at: "2026-10-30T20:35:05.025+0100",
               comment_author_id: "account-1",
               comment_author_name: "Person 1",
               issue_id: "46154",
               issue_key: "JCL-59",
               timestamp: "2026-10-30T19:35:05.025Z"
             }
    end

    test "comment_updated yields an update, never a creation" do
      assert {:ok, signal} = normalize("comment_updated")

      assert signal == %{
               event_type: "comment_updated",
               change_type: "updated",
               actor_id: "account-1",
               actor_name: "Person 1",
               comment_id: "42727",
               comment_body: "Capture comment, edited version.",
               comment_body_unsupported_nodes: [],
               comment_created_at: "2026-10-30T20:35:05.025+0100",
               comment_updated_at: "2026-10-30T20:35:07.443+0100",
               comment_author_id: "account-1",
               comment_author_name: "Person 1",
               issue_id: "46154",
               issue_key: "JCL-59",
               timestamp: "2026-10-30T19:35:07.443Z"
             }
    end

    test "the actor of an update is the update author, not the comment author" do
      # Derived: the captured edit with a second user as `updateAuthor`. In
      # the capture run the author edited their own comment.
      payload =
        update_in(payload!("comment_updated"), ["comment", "updateAuthor"], fn user ->
          %{user | "accountId" => "account-2", "displayName" => "Person 2"}
        end)

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert %{actor_id: "account-2", actor_name: "Person 2"} = signal
      assert %{comment_author_id: "account-1", comment_author_name: "Person 1"} = signal
    end

    test "an update without updateAuthor has no actor instead of the author" do
      # Derived: the captured edit without `updateAuthor`.
      payload =
        update_in(payload!("comment_updated"), ["comment"], &Map.delete(&1, "updateAuthor"))

      assert {:ok, signal} = Webhook.normalize_event(payload)
      refute Map.has_key?(signal, :actor_id)
      refute Map.has_key?(signal, :actor_name)
      assert signal.comment_author_id == "account-1"
    end

    test "a creation without author has neither actor nor author" do
      assert {:ok, baseline} = normalize("comment_created")

      # Derived: the captured creation without `comment.author`. Jira
      # documents the author on every comment; the normalizer reads a missing
      # author as absent rather than malformed.
      payload = update_in(payload!("comment_created"), ["comment"], &Map.delete(&1, "author"))

      assert {:ok, signal} = Webhook.normalize_event(payload)

      assert signal ==
               Map.drop(baseline, [
                 :actor_id,
                 :actor_name,
                 :comment_author_id,
                 :comment_author_name
               ])
    end

    test "administrator deliveries name no matched webhooks" do
      for name <- ~w(comment_created comment_updated) do
        assert {:ok, signal} = normalize(name)
        refute Map.has_key?(signal, :matched_webhook_ids)
        refute Map.has_key?(signal, :webhook_id)
      end
    end
  end

  describe "comment bodies" do
    test "a body over 512 bytes stays whole in the signal and is cut in the public map" do
      # Derived: the captured creation with its body repeated 20 times, 620 bytes.
      body = String.duplicate("Capture comment, first version.", 20)
      payload = put_in(payload!("comment_created"), ["comment", "body"], body)

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert byte_size(body) == 620
      assert signal.comment_body == body

      raw = Jason.encode!(payload)
      headers = %{"x-hub-signature" => sign(raw, LiveSmoke.replay_secret())}

      assert {:ok, %WebhookDelivery{normalized_signal: delivered} = delivery} =
               Webhook.verify_delivery(raw, headers, LiveSmoke.replay_secret())

      assert delivered.comment_body == body

      public = WebhookDelivery.to_public_map(delivery).normalized_signal["comment_body"]
      assert public == binary_part(body, 0, 512) <> "...[truncated 108 bytes]"
    end

    test "a body that projects to an empty text keeps comment_body" do
      # Derived: the captured creation with an empty body.
      payload = put_in(payload!("comment_created"), ["comment", "body"], "")

      assert {:ok, %{comment_body: "", comment_body_unsupported_nodes: []}} =
               Webhook.normalize_event(payload)
    end

    test "a comment without body has no comment_body" do
      # Derived: the captured creation without `body`.
      payload = update_in(payload!("comment_created"), ["comment"], &Map.delete(&1, "body"))

      assert {:ok, signal} = Webhook.normalize_event(payload)
      refute Map.has_key?(signal, :comment_body)
      refute Map.has_key?(signal, :comment_body_unsupported_nodes)
    end
  end

  describe "declared signal" do
    test "jira.comment.changed declares every field the captured deliveries yield" do
      schema = trigger("jira.comment.changed").signal_schema

      for name <- ~w(comment_created comment_updated) do
        assert {:ok, signal} = normalize(name)
        assert {:ok, ^signal} = Zoi.parse(schema, signal)
      end
    end

    test "jira.comment.changed declares the actor and matched webhook IDs" do
      fields = Map.new(trigger("jira.comment.changed").signal, &{&1.name, &1})

      assert %{type: :string, description: actor} = fields.actor_id
      assert actor =~ "updateAuthor"
      assert %{type: :string} = fields.actor_name
      assert %{type: {:array, :string}, description: matched} = fields.matched_webhook_ids
      assert matched =~ "Administrator webhooks"
      refute Map.has_key?(fields, :webhook_id)
    end
  end

  defp normalize(name), do: name |> payload!() |> Webhook.normalize_event()

  defp payload!(name), do: CapturedDelivery.payload!(name)

  defp trigger(id), do: Enum.find(Jido.Connect.Jira.integration().triggers, &(&1.id == id))

  defp sign(body, secret),
    do: "sha256=" <> (:hmac |> :crypto.mac(:sha256, secret, body) |> Base.encode16(case: :lower))
end
