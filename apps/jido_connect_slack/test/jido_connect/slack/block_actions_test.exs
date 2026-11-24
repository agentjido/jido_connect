defmodule Jido.Connect.Slack.BlockActionsTest do
  # Not async: the test that pins "no HTTP request" points the package's Req
  # options at a stub.
  use ExUnit.Case, async: false

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.{BlockAction, Interactivity}
  alias Jido.Connect.TestSupport.LiveSmoke

  import ExUnit.CaptureLog, only: [capture_log: 1]

  import Jido.Connect.Slack.TestSupport.CapturedDelivery,
    only: [capture!: 1, payload!: 1, replay: 1, replay: 2, derive: 2]

  # Captured from the Slack test workspace and sanitized by the block
  # actions live smoke test; see test/fixtures/slack/captured. The bot
  # posted "Button capture 1" and "Button capture 2", each with an Approve
  # and a Reject button, to the public channel, and the authorizing user
  # clicked Approve on each.
  @app "A0CDHUBBHRC"
  @team "T0CEE692400"
  @channel "C0CEEB41FU0"
  @clicking_user "U0CDPFT1RDJ"
  @author "U0CDHUEBVEJ"
  @second_user "U0CDEL6734M"
  @clicks ["block_actions_button_1", "block_actions_button_2"]

  # SHA-256 of the captured bodies, computed outside Elixir with Python's
  # hashlib.
  @delivery_ids %{
    "block_actions_button_1" =>
      "f78d370d3f10db09c69a1e0a44552861142411e607c67802911e081fec5efb71",
    "block_actions_button_2" => "498b296bc4683c550b3e316a13b04896839e0fef0b04dce66fa1fec7eb3fad49"
  }

  describe "a captured click" do
    test "names the clicking user, the message and the button exactly, in the signal and the struct" do
      expected = %{
        "block_actions_button_1" => %{
          api_app_id: @app,
          team_id: @team,
          user_id: @clicking_user,
          user_team_id: @team,
          channel_id: @channel,
          message_ts: "1793627512.599759",
          action_id: "jc_capture_approve",
          block_id: "jc_capture_decision_1",
          value: "capture-1:approve",
          action_ts: "1793627604.412086"
        },
        "block_actions_button_2" => %{
          api_app_id: @app,
          team_id: @team,
          user_id: @clicking_user,
          user_team_id: @team,
          channel_id: @channel,
          message_ts: "1793627512.787669",
          action_id: "jc_capture_approve",
          block_id: "jc_capture_decision_2",
          value: "capture-2:approve",
          action_ts: "1793627606.622080"
        }
      }

      for click <- @clicks do
        assert {:ok,
                %WebhookDelivery{event: "block_actions", normalized_signal: signal} = delivery} =
                 replay(click)

        assert signal == expected[click], click
        assert Interactivity.normalize_signal(delivery) == {:ok, signal}

        assert {:ok, %BlockAction{enterprise_id: nil, thread_ts: nil} = struct} =
                 BlockAction.new(signal)

        assert Map.take(Map.from_struct(struct), Map.keys(signal)) == signal
      end
    end

    # The payload names no installer. The captured clicker is the
    # authorizing user of the test workspace, who installed the app; the
    # message author is the bot user. A click by the second human user was
    # not captured.
    test "takes the clicking user from user.id, not from the message author in message.user" do
      for click <- @clicks do
        assert %{"user" => %{"id" => @clicking_user}, "message" => %{"user" => @author}} =
                 payload!(click)

        assert {:ok, %WebhookDelivery{normalized_signal: %{user_id: @clicking_user} = signal}} =
                 replay(click)

        refute @author in Map.values(signal)

        # Derived: the same click by the second human user.
        second = derive(click, &put_in(&1, ["user", "id"], @second_user))

        assert {:ok, %WebhookDelivery{normalized_signal: %{user_id: @second_user} = by_second}} =
                 replay(second)

        assert Map.delete(by_second, :user_id) == Map.delete(signal, :user_id)
      end
    end
  end

  describe "verify_delivery/4" do
    # Block actions are the first payload type that reads an option, so this
    # test fails when the transport passes [] to the normalizer.
    test "hands its options to the normalizer, which rejects a click for another app" do
      capture = capture!("block_actions_button_1")
      other_app = [api_app_id: "A0000000000"]

      assert {:ok, %WebhookDelivery{normalized_signal: %{api_app_id: @app}}} =
               replay(capture, api_app_id: @app, callback_ids: ["unused_by_block_actions"])

      assert {:ok, %WebhookDelivery{normalized_signal: nil} = delivery} =
               replay(capture, other_app)

      assert {:error,
              %Error.ProviderError{
                provider: :slack,
                reason: :unexpected_app,
                details: %{field: "api_app_id"}
              }} = Interactivity.normalize_signal(delivery, other_app)

      assert {:ok, %{api_app_id: @app}} = Interactivity.normalize_signal(delivery)
    end

    test "takes the delivery ID from the transport and marks a byte-identical redelivery" do
      for {click, id} <- @delivery_ids do
        assert {:ok, %WebhookDelivery{delivery_id: ^id, duplicate?: false}} = replay(click)

        assert {:ok, %WebhookDelivery{delivery_id: ^id, duplicate?: true, normalized_signal: %{}}} =
                 replay(click, seen_delivery_ids: [id])
      end
    end

    test "keeps clicks apart that differ in user, action, value, message or click time" do
      first_id = @delivery_ids["block_actions_button_1"]
      {:ok, %WebhookDelivery{normalized_signal: first}} = replay("block_actions_button_1")

      # Derived from the first click, one field changed each: the second
      # human user of the test workspace, the Reject button's action ID and
      # value, the second capture message, and a click one second later.
      variants = [
        user_id: derive_click(&put_in(&1, ["user", "id"], @second_user)),
        action_id: derive_click(&put_action(&1, "action_id", "jc_capture_reject")),
        value: derive_click(&put_action(&1, "value", "capture-1:reject")),
        message_ts: derive_click(&put_message_ts(&1, "1793627512.787669")),
        action_ts: derive_click(&put_action(&1, "action_ts", "1793627605.412086"))
      ]

      ids =
        for {field, capture} <- variants do
          assert {:ok,
                  %WebhookDelivery{delivery_id: id, duplicate?: false, normalized_signal: signal}} =
                   replay(capture, seen_delivery_ids: [first_id])

          assert Map.delete(signal, field) == Map.delete(first, field), "#{field}"
          refute signal[field] == first[field], "#{field}"
          id
        end

      second_id = @delivery_ids["block_actions_button_2"]

      assert {:ok, %WebhookDelivery{delivery_id: ^second_id, duplicate?: false}} =
               replay("block_actions_button_2", seen_delivery_ids: [first_id])

      assert length(Enum.uniq([first_id, second_id | ids])) == length(variants) + 2
    end
  end

  describe "a click that is no single button in a message" do
    test "fails with the payload path and verifies without a signal" do
      reject = %{"action_id" => "jc_capture_reject", "value" => "capture-1:reject"}

      # Derived from the first click: both buttons of the message in one
      # payload, no action, the action as a static select, and the click in
      # a modal view or a legacy attachment instead of a message.
      cases = [
        {derive_click(&update_in(&1, ["actions"], fn [a] -> [a, Map.merge(a, reject)] end)),
         "actions"},
        {derive_click(&Map.put(&1, "actions", [])), "actions"},
        {derive_click(&put_action(&1, "type", "static_select")), "actions.0.type"},
        {derive_click(&Map.put(&1, "container", %{"type" => "view", "view_id" => "V0000000001"})),
         "container.type"},
        {derive_click(&put_in(&1, ["container", "type"], "message_attachment")), "container.type"}
      ]

      for {capture, field} <- cases do
        assert_rejected(capture, :unsupported_block_action, %{field: field})
      end
    end

    test "fails for a button in an ephemeral message" do
      # Derived from the first click: the message posted ephemerally, for
      # which Slack marks the container and sends no message object. No such
      # click was captured.
      ephemeral =
        derive_click(fn payload ->
          payload
          |> put_in(["container", "is_ephemeral"], true)
          |> Map.delete("message")
        end)

      assert_rejected(ephemeral, :unsupported_block_action, %{field: "container.is_ephemeral"})
    end
  end

  describe "a click with a missing or malformed field" do
    @required ~w(api_app_id user.id container.channel_id container.message_ts channel.id
                 message.ts actions.0.action_id actions.0.block_id actions.0.value
                 actions.0.action_ts)

    test "fails with the payload path when a required field is missing, empty or no string" do
      # Derived from the first click: the field removed, empty, or a number.
      for field <- @required,
          change <- [&Map.delete(&1, &2), &Map.put(&1, &2, ""), &Map.put(&1, &2, 1_793_627_604)] do
        capture = derive_click(&change_at(&1, String.split(field, "."), change))
        assert_rejected(capture, :invalid_block_action, %{field: field})
      end
    end

    test "fails with the path of an object that is missing or no object" do
      # Derived from the first click: an object removed, or replaced by its ID.
      for {object, field} <- [
            {"user", "user.id"},
            {"channel", "channel.id"},
            {"message", "message.ts"},
            {"container", "container.type"}
          ] do
        assert_rejected(derive_click(&Map.delete(&1, object)), :invalid_block_action, %{
          field: field
        })
      end

      for {object, field} <- [
            {"user", "user"},
            {"channel", "channel"},
            {"message", "message"},
            {"container", "container"},
            {"enterprise", "enterprise"}
          ] do
        capture = derive_click(&Map.put(&1, object, "C0CEEB41FU0"))
        assert_rejected(capture, :invalid_block_action, %{field: field})
      end

      assert_rejected(
        derive_click(&Map.put(&1, "actions", ["jc_capture_approve"])),
        :invalid_block_action,
        %{field: "actions.0"}
      )

      assert_rejected(
        derive_click(&Map.put(&1, "actions", %{"0" => "jc_capture_approve"})),
        :invalid_block_action,
        %{field: "actions"}
      )
    end

    test "keeps optional IDs that are null or missing out of the signal" do
      # Derived from the first click: user.team_id removed, enterprise
      # removed instead of null.
      capture =
        derive_click(fn payload ->
          payload
          |> change_at(["user", "team_id"], &Map.delete(&1, &2))
          |> Map.delete("enterprise")
        end)

      assert {:ok, %WebhookDelivery{normalized_signal: signal}} = replay(capture)
      refute Map.has_key?(signal, :user_team_id)
      refute Map.has_key?(signal, :enterprise_id)
    end
  end

  describe "the message of a click" do
    @thread_ts "1793371034.447499"

    test "keeps the thread from the container or the message" do
      # Derived from the first click: the message as a reply in the prepared
      # thread, with thread_ts on the container, on the message, or on both.
      for change <- [
            &put_in(&1, ["container", "thread_ts"], @thread_ts),
            &put_in(&1, ["message", "thread_ts"], @thread_ts),
            &(&1
              |> put_in(["container", "thread_ts"], @thread_ts)
              |> put_in(["message", "thread_ts"], @thread_ts))
          ] do
        assert {:ok, %WebhookDelivery{normalized_signal: signal}} = replay(derive_click(change))
        assert %{thread_ts: @thread_ts, message_ts: "1793627512.599759"} = signal
        assert {:ok, %BlockAction{thread_ts: @thread_ts}} = BlockAction.new(signal)
      end
    end

    test "fails when the container and the message name different messages" do
      # Derived from the first click: one ID of the message changed.
      cases = [
        {&put_in(&1, ["channel", "id"], "C0CD4JEJ9V5"), "container.channel_id", "channel.id"},
        {&put_in(&1, ["message", "ts"], "1793627512.787669"), "container.message_ts",
         "message.ts"},
        {&(&1
           |> put_in(["container", "thread_ts"], @thread_ts)
           |> put_in(["message", "thread_ts"], "1793371020.846869")), "container.thread_ts",
         "message.thread_ts"}
      ]

      for {change, field, conflicts_with} <- cases do
        assert_rejected(derive_click(change), :conflicting_block_action, %{
          field: field,
          conflicts_with: conflicts_with
        })
      end
    end
  end

  describe "the installation of a click" do
    @enterprise %{"id" => "E0000000001", "name" => "name-3"}

    test "fails without a workspace, as for an org-wide install" do
      # Derived from the first click: Slack's org-wide install shape, with
      # team null and is_enterprise_install true, and the team removed,
      # null or without an ID.
      org_install = fn payload ->
        Map.merge(payload, %{
          "team" => nil,
          "enterprise" => @enterprise,
          "is_enterprise_install" => true
        })
      end

      cases = [
        {org_install, "is_enterprise_install"},
        {&Map.put(&1, "is_enterprise_install", true), "is_enterprise_install"},
        {&Map.delete(&1, "team"), "team.id"},
        {&Map.put(&1, "team", nil), "team.id"},
        {&put_in(&1, ["team", "id"], ""), "team.id"}
      ]

      for {change, field} <- cases do
        assert_rejected(derive_click(change), :no_workspace, %{field: field})
      end

      assert_rejected(derive_click(&put_in(&1, ["team", "id"], 1)), :invalid_block_action, %{
        field: "team.id"
      })
    end

    test "keeps the enterprise of a workspace install in an organization" do
      # Derived from the first click: the workspace as part of an
      # enterprise organization, still installed per workspace.
      capture = derive_click(&Map.put(&1, "enterprise", @enterprise))

      assert {:ok, %WebhookDelivery{normalized_signal: signal}} = replay(capture)
      assert %{enterprise_id: "E0000000001", team_id: @team} = signal
      assert {:ok, %BlockAction{enterprise_id: "E0000000001"}} = BlockAction.new(signal)
    end
  end

  describe "the length of a button's value and IDs" do
    # 2,000 characters in 3,000 bytes: "ä" takes two bytes in UTF-8.
    @long_value String.duplicate("ä", 1_000) <> String.duplicate("v", 1_000)
    @long_action_id String.duplicate("a", 255)
    @long_block_id String.duplicate("b", 255)

    test "a value of 2,000 characters and IDs of 255 survive in the signal and the struct" do
      assert {String.length(@long_value), byte_size(@long_value)} == {2_000, 3_000}

      # Derived from the first click: the clicked button with the longest
      # value and IDs Slack allows.
      capture =
        derive_click(fn payload ->
          payload
          |> put_action("value", @long_value)
          |> put_action("action_id", @long_action_id)
          |> put_action("block_id", @long_block_id)
        end)

      assert {:ok, %WebhookDelivery{normalized_signal: signal} = delivery} = replay(capture)

      assert %{value: @long_value, action_id: @long_action_id, block_id: @long_block_id} =
               signal

      assert {:ok,
              %BlockAction{
                value: @long_value,
                action_id: @long_action_id,
                block_id: @long_block_id
              }} = BlockAction.new(signal)

      # The public map bounds every binary at 512 bytes by design.
      assert %{normalized_signal: %{"value" => public_value}} =
               WebhookDelivery.to_public_map(delivery)

      assert public_value =~ "...[truncated "
      refute public_value == @long_value
    end

    test "one character more fails with the payload path" do
      # Derived from the first click: each limit exceeded by one character.
      for {field, too_long} <- [
            {"value", @long_value <> "v"},
            {"action_id", @long_action_id <> "a"},
            {"block_id", @long_block_id <> "b"}
          ] do
        assert_rejected(derive_click(&put_action(&1, field, too_long)), :invalid_block_action, %{
          field: "actions.0.#{field}"
        })
      end
    end
  end

  describe "the slack.interactivity.block_actions trigger" do
    @signal_fields [
      :api_app_id,
      :team_id,
      :enterprise_id,
      :user_id,
      :user_team_id,
      :channel_id,
      :message_ts,
      :thread_ts,
      :action_id,
      :block_id,
      :value,
      :action_ts
    ]

    test "takes bot auth and workspace access, needs no scope and names the block action fields" do
      assert {:ok, trigger} =
               Jido.Connect.trigger(Jido.Connect.Slack, "slack.interactivity.block_actions")

      assert %{
               kind: :webhook,
               resource: :block_action,
               verb: :watch,
               data_classification: :workspace_content,
               auth_profile: :bot,
               policies: [:workspace_access],
               scopes: [],
               scope_resolver: nil,
               handler: Jido.Connect.Slack.Handlers.Triggers.BlockActionsInteraction,
               verification: %{
                 kind: :slack_signed_request,
                 signature_header: "x-slack-signature",
                 timestamp_header: "x-slack-request-timestamp"
               },
               dedupe: %{
                 key: [
                   :team_id,
                   :channel_id,
                   :message_ts,
                   :user_id,
                   :block_id,
                   :action_id,
                   :value,
                   :action_ts
                 ]
               }
             } = trigger

      assert Enum.map(trigger.signal, & &1.name) == @signal_fields

      assert Enum.map(BlockAction.schema().fields, &elem(&1, 0)) |> Enum.sort() ==
               Enum.sort(@signal_fields)

      required = for field <- trigger.signal, field.required?, do: field.name

      assert required ==
               @signal_fields -- [:enterprise_id, :user_team_id, :thread_ts]
    end

    test "compiles into a metadata-only sensor" do
      sensor = Jido.Connect.Slack.Sensors.BlockActions

      assert sensor.trigger_id() == "slack.interactivity.block_actions"
      assert sensor.signal_type() == "slack.interactivity.block_actions"
      assert sensor.runtime_mode() == :metadata_only
      assert %{runtime_mode: :metadata_only} = sensor.jido_connect_projection()
    end

    test "accepts the signal of every captured click and of a click in a thread" do
      assert {:ok, %{signal_schema: schema}} =
               Jido.Connect.trigger(Jido.Connect.Slack, "slack.interactivity.block_actions")

      # Derived from the first click: the message as a reply in the prepared
      # thread of a workspace in an enterprise organization.
      threaded =
        derive_click(fn payload ->
          payload
          |> put_in(["container", "thread_ts"], "1793371034.447499")
          |> Map.put("enterprise", %{"id" => "E0000000001"})
        end)

      for capture <- [threaded | Enum.map(@clicks, &capture!/1)] do
        assert {:ok, %WebhookDelivery{normalized_signal: %{} = signal}} = replay(capture)
        assert {:ok, ^signal} = Zoi.parse(schema, signal)
      end
    end
  end

  describe "receipt of a click" do
    test "keeps token, response_url, trigger_id and the signing key out of deliveries, errors and logs" do
      attach_http_probe()
      stub_slack_api()

      for click <- @clicks do
        # The fixture keeps the fields, sanitized: token redacted,
        # response_url and trigger_id as placeholders.
        payload = payload!(click)

        assert %{"token" => "[redacted]", "response_url" => response_url, "trigger_id" => trigger} =
                 payload

        forbidden = [
          response_url,
          trigger,
          "response_url",
          "trigger_id",
          LiveSmoke.replay_secret()
        ]

        log =
          capture_log(fn ->
            assert {:ok, %WebhookDelivery{normalized_signal: %{}} = delivery} = replay(click)
            send(self(), {:delivery, delivery})

            # Derived from the click: a malformed, a conflicting and an
            # unsupported variant.
            for change <- [
                  &put_action(&1, "value", 42),
                  &put_in(&1, ["message", "ts"], "1793371034.447499"),
                  &put_action(&1, "type", "static_select")
                ] do
              {:ok, rejected} = replay(derive(click, change))
              assert {:error, error} = Interactivity.normalize_signal(rejected)
              send(self(), {:error, error})
            end
          end)

        assert_received {:delivery, delivery}
        refute Map.has_key?(delivery.payload, "token")
        refute Map.has_key?(delivery.payload, "response_url")
        refute Map.has_key?(delivery.payload, "trigger_id")

        texts = [
          inspect(delivery, limit: :infinity, printable_limit: :infinity),
          inspect(WebhookDelivery.to_public_map(delivery), limit: :infinity),
          inspect(delivery.normalized_signal),
          log
        ]

        errors =
          for _n <- 1..3 do
            assert_received {:error, error}

            [
              inspect(error, limit: :infinity, printable_limit: :infinity),
              inspect(Error.to_map(error)),
              Exception.message(error)
            ]
          end

        for text <- texts ++ List.flatten(errors), value <- forbidden do
          refute String.contains?(text, value), "#{click} leaks #{value}"
        end

        for error_text <- List.flatten(errors) do
          refute String.contains?(error_text, payload["actions"] |> hd() |> Map.fetch!("value"))
        end
      end

      refute_received {:http_request, _host}
    end
  end

  # A request through the package's Slack client fails the test.
  defp stub_slack_api do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})
    on_exit(fn -> Application.delete_env(:jido_connect_slack, :slack_req_options) end)
    Req.Test.stub(__MODULE__, fn _conn -> flunk("no request expected") end)
  end

  # Req sends every other HTTP request through Finch, which emits this event
  # in the calling process.
  defp attach_http_probe do
    handler_id = {__MODULE__, self(), make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:finch, :request, :start],
        &__MODULE__.handle_http_request/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  def handle_http_request(_event, _measurements, %{request: request}, test_pid) do
    if self() == test_pid, do: send(test_pid, {:http_request, request.host})
  end

  # The capture verifies, keeps `normalized_signal: nil`, and
  # `Interactivity.normalize_signal/2` names the reason.
  defp assert_rejected(capture, reason, details) do
    assert {:ok, %WebhookDelivery{normalized_signal: nil} = delivery} = replay(capture)

    assert {:error, %Error.ProviderError{provider: :slack, reason: ^reason, details: ^details}} =
             Interactivity.normalize_signal(delivery),
           "#{reason} #{inspect(details)}"
  end

  defp derive_click(change), do: derive("block_actions_button_1", change)

  # Applies `change.(map, key)` to the map that holds the last key of
  # `path`; "0" steps into the first list element.
  defp change_at(map, [key], change), do: change.(map, key)

  defp change_at(list, ["0" | rest], change) when is_list(list),
    do: List.update_at(list, 0, &change_at(&1, rest, change))

  defp change_at(map, [key | rest], change),
    do: Map.update!(map, key, &change_at(&1, rest, change))

  defp put_action(payload, key, value),
    do: update_in(payload, ["actions"], fn [action] -> [Map.put(action, key, value)] end)

  defp put_message_ts(payload, ts) do
    payload
    |> put_in(["container", "message_ts"], ts)
    |> put_in(["message", "ts"], ts)
  end
end
