defmodule Jido.Connect.Slack.MessageChangesTest do
  # Not async: the test that pins "no HTTP request" points the package's Req
  # options at a stub.
  use ExUnit.Case, async: false

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.Webhook
  alias Jido.Connect.TestSupport.LiveSmoke

  import Jido.Connect.Slack.TestSupport.CapturedDelivery,
    only: [capture!: 1, payload!: 1, replay: 1, derive: 2]

  # Captured from the Slack test workspace and sanitized by the message
  # ingress live smoke test; see test/fixtures/slack/captured. A person
  # posted `edit-public`, `edit-private`, `edit-dm`, `edit-group-dm` and the
  # thread reply `edit-thread`, edited each twice and deleted it. The bot
  # posted `edit-bot` and `edit-bot-empty`, edited them with chat.update and
  # deleted them with chat.delete. It also posted two thread parents with a
  # reply each and deleted the parents, one after an edit, and then the
  # replies.

  describe "an edit" do
    test "keeps the edited message's ts, its full text, its author and its editor" do
      payload = payload!("message_changed_public")

      assert {:ok, %WebhookDelivery{event: "message", normalized_signal: delivered}} =
               replay("message_changed_public")

      signal = Map.delete(delivered, :delivery)

      assert signal == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CDZKJCP45",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_changed",
               ts: "1793628161.214619",
               user: "U0CDPFT1RDJ",
               editor: "U0CDPFT1RDJ",
               edited_ts: "1793628168.000000",
               text: payload["event"]["message"]["text"],
               notification_ts: "1793628168.004800",
               event_ts: "1793628168.004800",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }

      assert byte_size(signal.text) == 683
      assert String.starts_with?(signal.text, "edit-public Live capture")
    end

    test "by the bot keeps the bot as author and editor, with bot_id and app_id" do
      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} = replay("message_changed_bot")

      assert Map.delete(delivered, :delivery) == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CE82FNUCR",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_changed",
               ts: "1793634980.384559",
               user: "U0CDHUEBVEJ",
               bot_id: "B0CDHUEB8MC",
               app_id: "A0CDHUBBHRC",
               editor: "U0CDHUEBVEJ",
               edited_ts: "1793634988.000000",
               text: payload!("message_changed_bot")["event"]["message"]["text"],
               notification_ts: "1793634988.000100",
               event_ts: "1793634988.000100",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }
    end

    test "to an empty text beside an attachment keeps the text as an empty string" do
      payload = payload!("message_changed_bot_empty_text")
      assert %{"text" => "", "attachments" => [_attachment]} = payload["event"]["message"]

      assert {:ok, %WebhookDelivery{normalized_signal: %{text: ""} = delivered}} =
               replay("message_changed_bot_empty_text")

      signal = Map.delete(delivered, :delivery)
      assert {:ok, ^signal} = Webhook.normalize_signal("message.channels.changed", payload)
      assert %{ts: "1793635033.825559", editor: "U0CDHUEBVEJ", bot_id: "B0CDHUEB8MC"} = signal
    end

    test "by another person than the author keeps both" do
      # Derived: the captured public edit as the second user's edit of the
      # authorizing user's message. Slack lets only some workspace admins
      # edit another person's message, so no such edit was captured.
      capture =
        derive(
          "message_changed_public",
          &put_in(&1, ["event", "message", "edited", "user"], "U0CDEL6734M")
        )

      assert {:ok, %WebhookDelivery{normalized_signal: signal}} = replay(capture)
      assert %{user: "U0CDPFT1RDJ", editor: "U0CDEL6734M", ts: "1793628161.214619"} = signal
    end
  end

  describe "a deletion" do
    test "keeps the deleted message's ts and author, and no text" do
      previous = payload!("message_deleted_thread_reply")["event"]["previous_message"]

      assert {:ok, %WebhookDelivery{event: "message", normalized_signal: delivered}} =
               replay("message_deleted_thread_reply")

      signal = Map.delete(delivered, :delivery)

      assert signal == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CDZMS9N77",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_deleted",
               ts: "1793628275.471009",
               thread_ts: "1793627736.679599",
               user: "U0CDPFT1RDJ",
               notification_ts: "1793628616.005400",
               event_ts: "1793628616.005400",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }

      assert String.starts_with?(previous["text"], "edit-thread ")
      refute_text(signal, previous["text"])
    end

    test "of a bot message keeps the bot as author" do
      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} = replay("message_deleted_bot")

      assert Map.delete(delivered, :delivery) == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CDQPZ092B",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_deleted",
               ts: "1793634980.384559",
               user: "U0CDHUEBVEJ",
               bot_id: "B0CDHUEB8MC",
               app_id: "A0CDHUBBHRC",
               notification_ts: "1793635005.000300",
               event_ts: "1793635005.000300",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }
    end

    test "needs no previous_message, but then names neither author nor thread" do
      # Derived: the captured deletion of the thread reply without the
      # `previous_message` Slack sent with it.
      capture =
        derive(
          "message_deleted_thread_reply",
          &update_in(&1, ["event"], fn event ->
            Map.delete(event, "previous_message")
          end)
        )

      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} = replay(capture)

      assert Map.delete(delivered, :delivery) == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CDZMS9N77",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_deleted",
               ts: "1793628275.471009",
               notification_ts: "1793628616.005400",
               event_ts: "1793628616.005400",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }
    end
  end

  describe "the deletion of a thread parent with replies" do
    # The bot posted a thread parent, replied to it and deleted the parent
    # with chat.delete, once without and once after an edit. Slack kept a
    # tombstone in place of the parent and sent it as a `message_changed`.
    # After the last reply was deleted, it removed the tombstone with a
    # `message_deleted` whose `previous_message` is the tombstone.

    test "arrives as a tombstone and keeps the parent's ts and author, and no text" do
      payload = payload!("message_changed_tombstone")
      %{"message" => tombstone, "previous_message" => previous} = payload["event"]
      assert %{"subtype" => "tombstone", "user" => "USLACKBOT"} = tombstone

      assert {:ok, %WebhookDelivery{event: "message", normalized_signal: delivered}} =
               replay("message_changed_tombstone")

      signal = Map.delete(delivered, :delivery)

      assert signal == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CF11H3GGY",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_deleted",
               ts: "1793637515.439379",
               thread_ts: "1793637515.439379",
               user: "U0CDHUEBVEJ",
               bot_id: "B0CDHUEB8MC",
               app_id: "A0CDHUBBHRC",
               notification_ts: "1793637527.000200",
               event_ts: "1793637527.000200",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }

      for event <- ["message", "message.channels.deleted"] do
        assert {:ok, ^signal} = Webhook.normalize_signal(event, payload), event
      end

      assert {:ok, ^signal} = Webhook.normalize_event(payload)
      refute_text(signal, previous["text"])
      refute_text(signal, tombstone["text"])
    end

    test "after an edit names neither editor nor edit time" do
      assert %{"edited" => %{"ts" => _edited_ts}} =
               payload!("message_changed_tombstone_edited")["event"]["previous_message"]

      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} =
               replay("message_changed_tombstone_edited")

      assert Map.delete(delivered, :delivery) == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CE6EWN4N6",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_deleted",
               ts: "1793637591.015939",
               thread_ts: "1793637591.015939",
               user: "U0CDHUEBVEJ",
               bot_id: "B0CDHUEB8MC",
               app_id: "A0CDHUBBHRC",
               notification_ts: "1793637605.000700",
               event_ts: "1793637605.000700",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }
    end

    test "as a tombstone is no edit, and only its own family's deletion trigger takes it" do
      for fixture <- ~w(message_changed_tombstone message_changed_tombstone_edited) do
        payload = payload!(fixture)

        assert {:error, %Error.ProviderError{reason: :not_an_edit} = error} =
                 Webhook.normalize_signal("message.channels.changed", payload)

        refute_text(error, payload["event"]["previous_message"]["text"])

        for family <- ~w(message.groups message.im message.mpim), action <- ~w(changed deleted) do
          assert {:error,
                  %Error.ProviderError{
                    reason: :unsupported_channel_type,
                    details: %{channel_type: "channel"}
                  }} = Webhook.normalize_signal("#{family}.#{action}", payload),
                 "#{fixture} #{family}.#{action}"
        end

        assert {:error,
                %Error.ProviderError{
                  reason: :unsupported_message_subtype,
                  details: %{subtype: "message_changed"}
                }} = Webhook.normalize_signal("message.channels", payload)
      end
    end

    test "ends with the removal of the tombstone, a second deletion that names no author" do
      payload = payload!("message_deleted_tombstone")

      assert %{"subtype" => "tombstone", "user" => "USLACKBOT"} =
               payload["event"]["previous_message"]

      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} =
               replay("message_deleted_tombstone")

      signal = Map.delete(delivered, :delivery)

      assert signal == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CE0DCKK5Z",
               channel: "C0CEEB41FU0",
               channel_type: "channel",
               subtype: "message_deleted",
               ts: "1793637515.439379",
               thread_ts: "1793637515.439379",
               notification_ts: "1793637559.000400",
               event_ts: "1793637559.000400",
               view: "bot",
               viewer: "U0CDHUEBVEJ"
             }

      assert {:ok, ^signal} = Webhook.normalize_event(payload)
      assert {:ok, ^signal} = Webhook.normalize_signal("message.channels.deleted", payload)

      {:ok, deleted} = Webhook.normalize_event(payload!("message_changed_tombstone"))
      assert deleted.ts == signal.ts
      refute deleted.event_id == signal.event_id
    end
  end

  describe "in each conversation class" do
    # {fixture name suffix, trigger family, channel, channel_type, source ts}
    @families [
      {"public", "message.channels", "C0CEEB41FU0", "channel", "1793628161.214619"},
      {"private", "message.groups", "C0CD4JEJ9V5", "group", "1793628198.234269"},
      {"im", "message.im", "D0CD4G48UFR", "im", "1793628218.763049"},
      {"mpim", "message.mpim", "C0CDELYPYKF", "mpim", "1793628245.298689"},
      {"thread_reply", "message.channels", "C0CEEB41FU0", "channel", "1793628275.471009"}
    ]

    test "edits and the deletion keep the source ts, apart from the notification ts" do
      for {name, family, channel, channel_type, source_ts} <- @families,
          {fixture, action} <- [
            {"message_changed_#{name}", "changed"},
            {"message_changed_#{name}_2", "changed"},
            {"message_deleted_#{name}", "deleted"}
          ] do
        payload = payload!(fixture)

        assert {:ok, %WebhookDelivery{normalized_signal: delivered}} = replay(fixture)
        signal = Map.delete(delivered, :delivery)

        assert {:ok, ^signal} = Webhook.normalize_event(payload), fixture
        assert {:ok, ^signal} = Webhook.normalize_signal("#{family}.#{action}", payload), fixture

        assert %{channel: ^channel, channel_type: ^channel_type, ts: ^source_ts} = signal,
               fixture

        assert signal.notification_ts == payload["event"]["ts"]
        refute signal.notification_ts == source_ts
      end
    end

    test "two edits and a deletion of a message and of a thread reply have their own event IDs" do
      rows = [
        {"public", nil, ~w(Ev0CDZKJCP45 Ev0CEZ9TD7A4 Ev0CE6TBSZU1)},
        {"thread_reply", "1793627736.679599", ~w(Ev0CE8KWFBJQ Ev0CEZACEF7A Ev0CDZMS9N77)}
      ]

      for {name, thread_ts, event_ids} <- rows do
        signals =
          for fixture <- [
                "message_changed_#{name}",
                "message_changed_#{name}_2",
                "message_deleted_#{name}"
              ] do
            {:ok, signal} = Webhook.normalize_event(payload!(fixture))
            signal
          end

        assert Enum.map(signals, & &1.event_id) == event_ids
        assert [%{ts: ts}, %{ts: ts}, %{ts: ts}] = signals
        assert Enum.map(signals, &Map.get(&1, :thread_ts)) == [thread_ts, thread_ts, thread_ts]

        assert Enum.map(signals, & &1.subtype) ==
                 ~w(message_changed message_changed message_deleted)
      end
    end
  end

  describe "the conversation class" do
    @classes [
      {"public", "message.channels", "channel"},
      {"private", "message.groups", "group"},
      {"im", "message.im", "im"},
      {"mpim", "message.mpim", "mpim"}
    ]

    test "of another trigger family is rejected, an unknown one also on the generic path" do
      for {name, _family, channel_type} <- @classes,
          {fixture, action} <- [
            {"message_changed_#{name}", "changed"},
            {"message_deleted_#{name}", "deleted"}
          ],
          {_other, family, other_type} <- @classes,
          other_type != channel_type do
        assert {:error,
                %Error.ProviderError{
                  reason: :unsupported_channel_type,
                  details: %{channel_type: ^channel_type}
                }} = Webhook.normalize_signal("#{family}.#{action}", payload!(fixture)),
               "#{fixture} under #{family}"
      end

      # Derived: the captured public edit with the channel type of the App
      # Home tab, which no message trigger serves.
      app_home = put_in(payload!("message_changed_public"), ["event", "channel_type"], "app_home")

      assert {:error,
              %Error.ProviderError{
                reason: :unsupported_channel_type,
                details: %{channel_type: "app_home"}
              }} = Webhook.normalize_event(app_home)
    end

    test "is a public channel when channel_type is missing, as for message.channels" do
      for {fixture, action} <- [
            {"message_changed_public", "changed"},
            {"message_deleted_public", "deleted"}
          ] do
        # Derived: the captured public edit and deletion without
        # `channel_type`.
        payload = update_in(payload!(fixture), ["event"], &Map.delete(&1, "channel_type"))

        assert {:ok, signal} = Webhook.normalize_event(payload)
        refute Map.has_key?(signal, :channel_type)
        assert {:ok, ^signal} = Webhook.normalize_signal("message.channels.#{action}", payload)

        for family <- ~w(message.groups message.im message.mpim) do
          assert {:error,
                  %Error.ProviderError{
                    reason: :unsupported_channel_type,
                    details: %{channel_type: nil}
                  }} = Webhook.normalize_signal("#{family}.#{action}", payload)
        end
      end
    end
  end

  describe "a change trigger" do
    test "takes only its own subtype and only event callbacks" do
      rows = [
        {"message.channels.changed", payload!("message_deleted_public"), "message_deleted"},
        {"message.channels.deleted", payload!("message_changed_public"), "message_changed"},
        {"message.channels.changed", payload!("message_public"), nil},
        {"message.im.deleted", payload!("message_im"), nil},
        {"message.channels.changed", payload!("message_file_share"), "file_share"}
      ]

      for {event, payload, subtype} <- rows do
        assert {:error,
                %Error.ProviderError{
                  reason: :unsupported_message_subtype,
                  details: %{subtype: ^subtype}
                }} = Webhook.normalize_signal(event, payload),
               event
      end

      # Derived: Slack's url_verification body with the capture's redacted
      # token.
      challenge = %{
        "token" => payload!("message_changed_public")["token"],
        "challenge" => "jc-capture-challenge",
        "type" => "url_verification"
      }

      assert {:error, %Error.ProviderError{reason: :unsupported_event}} =
               Webhook.normalize_signal("message.channels.changed", challenge)

      assert {:error, %Error.ProviderError{reason: :unsupported_event}} =
               Webhook.normalize_signal("message.channels.changed", payload!("app_mention"))
    end
  end

  describe "a malformed change" do
    test "fails on every path with the payload path of the field, and yields no signal" do
      edit = "message_changed_thread_reply"
      deletion = "message_deleted_thread_reply"
      tombstone = "message_changed_tombstone"

      # Derived: the captured edit and deletion of the thread reply and the
      # captured tombstone with one field left out, emptied or of another
      # type.
      rows = [
        {edit, "changed", &Map.delete(&1, "team_id"), "team_id"},
        {deletion, "deleted", &Map.put(&1, "event_id", ""), "event_id"},
        {edit, "changed", &put_in(&1, ["event", "channel"], 42), "event.channel"},
        {edit, "changed",
         &update_in(&1, ["event", "message"], fn message ->
           Map.delete(message, "ts")
         end), "event.message.ts"},
        {edit, "changed", &put_in(&1, ["event", "message", "ts"], 1_793_628_275.471009),
         "event.message.ts"},
        {deletion, "deleted",
         &update_in(&1, ["event"], fn event ->
           Map.delete(event, "deleted_ts")
         end), "event.deleted_ts"},
        {edit, "changed", &put_in(&1, ["event", "message"], "edit-thread"), "event.message"},
        {edit, "changed", &put_in(&1, ["event", "message", "edited"], "U0CDPFT1RDJ"),
         "event.message.edited"},
        {edit, "changed", &put_in(&1, ["event", "message", "edited", "user"], ["U0CDPFT1RDJ"]),
         "event.message.edited.user"},
        {edit, "changed", &put_in(&1, ["event", "message", "text"], %{"type" => "mrkdwn"}),
         "event.message.text"},
        {edit, "changed", &put_in(&1, ["event", "message", "thread_ts"], 1_793_627_736),
         "event.message.thread_ts"},
        {deletion, "deleted", &put_in(&1, ["event", "previous_message"], []),
         "event.previous_message"},
        {edit, "changed", &put_in(&1, ["event", "previous_message"], "edit-thread"),
         "event.previous_message"},
        {edit, "changed", &put_in(&1, ["event", "previous_message", "ts"], 1_793_628_275),
         "event.previous_message.ts"},
        {edit, "changed", &put_in(&1, ["event", "previous_message", "edited"], "U0CDPFT1RDJ"),
         "event.previous_message.edited"},
        {deletion, "deleted", &put_in(&1, ["event", "previous_message", "user"], 7),
         "event.previous_message.user"},
        {deletion, "deleted", &put_in(&1, ["event", "event_ts"], 1_793_628_616),
         "event.event_ts"},
        {tombstone, "deleted",
         &update_in(&1, ["event", "message"], fn message ->
           Map.delete(message, "ts")
         end), "event.message.ts"},
        {tombstone, "deleted", &put_in(&1, ["event", "previous_message", "bot_id"], 7),
         "event.previous_message.bot_id"}
      ]

      for {fixture, action, change, field} <- rows do
        capture = derive(fixture, change)
        payload = Jason.decode!(capture["body"])

        for result <- [
              Webhook.normalize_event(payload),
              Webhook.normalize_signal("message.channels.#{action}", payload)
            ] do
          assert {:error,
                  %Error.ProviderError{reason: :invalid_message_change, details: details} =
                    error} = result,
                 field

          assert details == %{field: field}
          refute_text(error, payload!(edit)["event"]["message"]["text"])
        end

        assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: nil}} =
                 replay(capture),
               field
      end
    end

    test "that names two different messages fails with both payload paths" do
      # Derived: the captured edit, deletion and tombstone whose
      # `previous_message` names another message than the change.
      rows = [
        {"message_changed_public", "changed", "event.message.ts"},
        {"message_deleted_public", "deleted", "event.deleted_ts"},
        {"message_changed_tombstone", "deleted", "event.message.ts"}
      ]

      for {fixture, action, field} <- rows do
        capture =
          derive(fixture, &put_in(&1, ["event", "previous_message", "ts"], "1793627736.679599"))

        payload = Jason.decode!(capture["body"])

        for result <- [
              Webhook.normalize_event(payload),
              Webhook.normalize_signal("message.channels.#{action}", payload)
            ] do
          assert {:error,
                  %Error.ProviderError{
                    reason: :conflicting_message_change,
                    details: %{field: ^field, conflicts_with: "event.previous_message.ts"}
                  } = error} = result

          refute_text(error, payload["event"]["previous_message"]["text"])
        end

        assert {:ok, %WebhookDelivery{normalized_signal: nil}} = replay(capture)
      end
    end
  end

  describe "a message_changed event without message.edited" do
    # A thread parent's new reply count after `edit-thread` was deleted, a
    # broadcast reply's update of its thread root, and a link unfurl in a DM
    # of the authorizing user.
    @unedited [
      {"message_changed_thread_parent", "message.channels"},
      {"message_changed_broadcast_root", "message.channels"},
      {"message_changed_unfurl", "message.im"}
    ]

    test "is no edit on every path and yields no signal" do
      for {fixture, family} <- @unedited do
        payload = payload!(fixture)
        refute Map.has_key?(payload["event"]["message"], "edited")

        for result <- [
              Webhook.normalize_event(payload),
              Webhook.normalize_signal("message", payload),
              Webhook.normalize_signal("#{family}.changed", payload)
            ] do
          assert {:error, %Error.ProviderError{reason: :not_an_edit} = error} = result, fixture
          refute_text(error, payload["event"]["message"]["text"])
        end

        assert {:ok,
                %WebhookDelivery{
                  event: "message",
                  signature_state: :verified,
                  normalized_signal: nil
                }} = replay(fixture)
      end
    end
  end

  describe "a message_changed event of a message edited before" do
    # Slack keeps `edited` on a message after an edit. A later reply count,
    # broadcast root update or unfurl of that message carries the last edit
    # again, in `message` and in `previous_message`.

    test "that repeats the last edit is no edit on every path and yields no signal" do
      edited = %{"user" => "U0CDPFT1RDJ", "ts" => "1793628100.000000"}

      for {fixture, family} <- @unedited do
        # Derived: the captured change of an unedited message, with the same
        # `edited` in `message` and `previous_message`.
        capture =
          derive(fixture, fn payload ->
            payload
            |> put_in(["event", "message", "edited"], edited)
            |> put_in(["event", "previous_message", "edited"], edited)
          end)

        payload = Jason.decode!(capture["body"])

        for result <- [
              Webhook.normalize_event(payload),
              Webhook.normalize_signal("message", payload),
              Webhook.normalize_signal("#{family}.changed", payload)
            ] do
          assert {:error, %Error.ProviderError{reason: :not_an_edit}} = result, fixture
        end

        assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: nil}} =
                 replay(capture),
               fixture
      end
    end

    test "is an edit when edited.ts or the text differs from previous_message" do
      {:ok, %WebhookDelivery{normalized_signal: edit}} = replay("message_changed_public_2")
      payload = payload!("message_changed_public_2")
      %{"message" => message, "previous_message" => previous} = payload["event"]
      refute message["edited"] == previous["edited"]
      refute message["text"] == previous["text"]

      # Derived: the captured second edit of the public message, once with
      # the `edited` of the first edit, as for two edits within one second,
      # once with the text before the edit, as for an edit of only blocks or
      # attachments, and once without `previous_message`.
      changes = [
        &put_in(&1, ["event", "previous_message", "edited"], message["edited"]),
        &put_in(&1, ["event", "previous_message", "text"], message["text"]),
        &update_in(&1, ["event"], fn event -> Map.delete(event, "previous_message") end)
      ]

      for change <- changes do
        capture = derive("message_changed_public_2", change)
        payload = Jason.decode!(capture["body"])

        assert {:ok, %WebhookDelivery{normalized_signal: delivered}} = replay(capture)
        signal = Map.delete(delivered, :delivery)

        assert signal == Map.delete(edit, :delivery)
        assert {:ok, ^signal} = Webhook.normalize_event(payload)
        assert {:ok, ^signal} = Webhook.normalize_signal("message.channels.changed", payload)
      end
    end
  end

  describe "every captured change" do
    @changes ~w(public private im mpim thread_reply bot)
             |> Enum.flat_map(
               &["message_changed_#{&1}", "message_changed_#{&1}_2", "message_deleted_#{&1}"]
             )
             |> Kernel.++(~w(message_changed_bot_empty_text message_deleted_bot_empty_text
                  message_changed_thread_parent message_changed_broadcast_root
                  message_changed_unfurl message_changed_tombstone
                  message_changed_tombstone_edited message_deleted_tombstone))

    test "verifies only with its signature, unchanged and in time" do
      for fixture <- @changes do
        %{"body" => body, "headers" => headers, "captured_at" => now} = capture!(fixture)
        secret = LiveSmoke.replay_secret()
        timestamp = String.to_integer(headers["x-slack-request-timestamp"])

        # Derived: the captured body with the edited or deleted message's ts
        # changed, under the captured signature.
        tampered = String.replace(body, ~s("ts":"1793), ~s("ts":"1794))
        refute tampered == body

        assert {:error, %Error.AuthError{reason: :invalid_signature}} =
                 Webhook.verify_delivery(tampered, headers, secret, now: now),
               fixture

        for stale <- [timestamp + 301, timestamp - 301] do
          assert {:error, %Error.AuthError{reason: :stale_timestamp}} =
                   Webhook.verify_delivery(body, headers, secret, now: stale),
                 fixture
        end
      end
    end

    test "yields a signal that the signal schema of its trigger accepts" do
      triggers = Jido.Connect.Slack.integration().triggers

      for fixture <- @changes,
          payload = payload!(fixture),
          {:ok, signal} <- [Webhook.normalize_event(payload)] do
        id = "slack.event.#{trigger_event(payload)}"
        trigger = Enum.find(triggers, &(&1.id == id))

        assert {:ok, ^signal} = Zoi.parse(trigger.signal_schema, signal), "#{id} #{fixture}"
      end
    end

    test "deletion signals and errors leave out the message text" do
      for fixture <- @changes,
          payload = payload!(fixture),
          {:ok, %{subtype: "message_deleted"} = signal} <- [Webhook.normalize_event(payload)] do
        refute Map.has_key?(signal, :text)
        edit_trigger = String.replace_suffix(trigger_event(payload), ".deleted", ".changed")

        # Derived: the deletion with a `previous_message` that names another
        # message, and with an `event_ts` that is no string.
        errors = [
          Webhook.normalize_signal(edit_trigger, payload),
          Webhook.normalize_event(
            put_in(payload, ["event", "previous_message", "ts"], "1793627736.679599")
          ),
          Webhook.normalize_event(put_in(payload, ["event", "event_ts"], 1_793_628_616))
        ]

        for result <- errors do
          assert {:error, %Error.ProviderError{}} = result, fixture
        end

        with %{"text" => text} when text != "" <- payload["event"]["previous_message"] do
          refute_text(signal, text)
          for {:error, error} <- errors, do: refute_text(error, text)
        end
      end
    end

    test "normalizes without an HTTP request" do
      Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})
      on_exit(fn -> Application.delete_env(:jido_connect_slack, :slack_req_options) end)
      Req.Test.stub(__MODULE__, fn _conn -> flunk("no request expected") end)

      for fixture <- @changes do
        payload = payload!(fixture)

        assert {:ok, %WebhookDelivery{}} = replay(fixture)
        assert {_ok_or_error, _result} = Webhook.normalize_event(payload)
        assert {_ok_or_error, _result} = Webhook.normalize_signal(trigger_event(payload), payload)
      end
    end
  end

  # The change trigger event for `payload`, such as message.channels.changed.
  defp trigger_event(%{"event" => event}) do
    action =
      if event["subtype"] == "message_changed" and event["message"]["subtype"] != "tombstone",
        do: "changed",
        else: "deleted"

    "#{family(event["channel_type"])}.#{action}"
  end

  defp family("channel"), do: "message.channels"
  defp family("group"), do: "message.groups"
  defp family("im"), do: "message.im"
  defp family("mpim"), do: "message.mpim"

  # No value of `term`, at any depth, holds `text` or a piece of it.
  defp refute_text(term, text) do
    piece = String.slice(text, 0, 40)
    refute inspect(term, limit: :infinity, printable_limit: :infinity) =~ piece
  end
end
