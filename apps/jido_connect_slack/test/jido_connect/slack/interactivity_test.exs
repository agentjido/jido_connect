defmodule Jido.Connect.Slack.InteractivityTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.{Interactivity, Webhook}
  alias Jido.Connect.Slack.Interactivity.Normalizer

  # Signing secret, request timestamp, raw body and signature from
  # https://api.slack.com/authentication/verifying-requests-from-slack
  # verbatim. The documented body is a slash command, not an interactivity
  # form, so it carries no payload field.
  @doc_secret "8f742231b10e8888abcd99yyyzzz85a5"
  @doc_timestamp "1531420618"
  @doc_now 1_531_420_618
  @doc_body "token=xyzz0WbapA4vBCDEFasx0q6G&team_id=T1DC2JH3J&team_domain=testteamnow&channel_id=G8PSS9T3V&channel_name=foobar&user_id=U2CERLKJA&user_name=roadrunner&command=%2Fwebhook-collect&text=&response_url=https%3A%2F%2Fhooks.slack.com%2Fcommands%2FT1DC2JH3J%2F397700885554%2F96rGlfmibIGlgcZRskXaIFfN&trigger_id=398738663015.47445629121.803a0bc887a14d10d2c447fce8b6703c"
  @doc_signature "v0=a2114d57b48eac39b9ad189dd8316235a7b4a8d21a10bd27519666489c69b503"

  # First example payload (message container) from
  # https://api.slack.com/reference/interaction-payloads/block-actions
  # verbatim. Slack documents no signed form body for it, so the test
  # form-encodes it and signs it with the documented secret and timestamp.
  @block_actions_payload String.replace_suffix(
                           ~S"""
                           {
                               "type": "block_actions",
                               "team": {
                                   "id": "T9TK3CUKW",
                                   "domain": "example"
                               },
                               "user": {
                                   "id": "UA8RXUSPL",
                                   "username": "jtorrance",
                                   "team_id": "T9TK3CUKW"
                               },
                               "api_app_id": "AABA1ABCD",
                               "token": "9s8d9as89d8as9d8as989",
                               "container": {
                                   "type": "message_attachment",
                                   "message_ts": "1548261231.000200",
                                   "attachment_id": 1,
                                   "channel_id": "CBR2V3XEX",
                                   "is_ephemeral": false,
                                   "is_app_unfurl": false
                               },
                               "trigger_id": "12321423423.333649436676.d8c1bb837935619ccad0f624c448ffb3",
                               "channel": {
                                   "id": "CBR2V3XEX",
                                   "name": "review-updates"
                               },
                               "message": {
                                   "bot_id": "BAH5CA16Z",
                                   "type": "message",
                                   "text": "This content can't be displayed.",
                                   "user": "UAJ2RU415",
                                   "ts": "1548261231.000200"
                               },
                               "response_url": "https://hooks.slack.com/actions/AABA1ABCD/1232321423432/D09sSasdasdAS9091209",
                               "actions": [
                                   {
                                       "action_id": "WaXA",
                                       "block_id": "=qXel",
                                       "text": {
                                           "type": "plain_text",
                                           "text": "View",
                                           "emoji": true
                                       },
                                       "value": "click_me_123",
                                       "type": "button",
                                       "action_ts": "1548426417.840180"
                                   }
                               ]
                           }
                           """,
                           "\n",
                           ""
                         )

  # Global shortcut example from
  # https://api.slack.com/reference/interaction-payloads/shortcuts
  # verbatim; form-encoded and signed by the test like the block_actions one.
  @shortcut_payload String.replace_suffix(
                      ~S"""
                      {
                          "type": "shortcut",
                          "token": "XXXXXXXXXXXXX",
                          "action_ts": "1581106241.371594",
                          "team": {
                              "id": "TXXXXXXXX",
                              "domain": "shortcuts-test"
                          },
                          "user": {
                              "id": "UXXXXXXXXX",
                              "username": "aman",
                              "team_id": "TXXXXXXXX"
                          },
                          "callback_id": "shortcut_create_task",
                          "trigger_id": "944799105734.773906753841.38b5894552bdd4a780554ee59d1f3638"
                      }
                      """,
                      "\n",
                      ""
                    )

  # Message shortcut example from
  # https://api.slack.com/reference/interaction-payloads/shortcuts
  # verbatim; form-encoded and signed by the test like the block_actions one.
  @message_action_payload String.replace_suffix(
                            ~S"""
                            {
                                "token": "Nj2rfC2hU8mAfgaJLemZgO7H",
                                "callback_id": "chirp_message",
                                "type": "message_action",
                                "trigger_id": "13345224609.8534564800.6f8ab1f53e13d0cd15f96106292d5536",
                                "response_url": "https://hooks.slack.com/app-actions/T0MJR11A4/21974584944/yk1S9ndf35Q1flupVG5JbpM6",
                                "team": {
                                    "id": "T0MJRM1A7",
                                    "domain": "pandamonium"
                                },
                                "channel": {
                                    "id": "D0LFFBKLZ",
                                    "name": "cats"
                                },
                                "user": {
                                    "id": "U0D15K92L",
                                    "name": "dr_maomao"
                                },
                                "message": {
                                    "type": "message",
                                    "user": "U0MJRG1AL",
                                    "ts": "1516229207.000133",
                                    "text": "World's smallest big cat! <https://youtube.com/watch?v=W86cTIoMv2U>"
                                }
                            }
                            """,
                            "\n",
                            ""
                          )

  # view_submission example from
  # https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload
  # verbatim; form-encoded and signed by the test like the block_actions one.
  # The example carries response_urls under view, while the property table on
  # the same page lists the field at the top level of the payload.
  @view_submission_payload String.replace_suffix(
                             ~S"""
                             {
                                 "type": "view_submission",
                                 "team": {
                                     "id": "T1234567",
                                     "domain": "example-domain"
                                 },
                                 "user": {
                                     "id": "U1234567",
                                     "username": "example-user"
                                 },
                                 "view": {
                                     "id": "VNHU13V36",
                                     "type": "modal",
                                     "title": {
                                         "type": "plain_text",
                                         "text": "Modal Title"
                                     },
                                     "submit": {
                                         "type": "plain_text",
                                         "text": "Submit"
                                     },
                                     "blocks": [],
                                     "private_metadata": "shhh-its-secret",
                                     "callback_id": "modal-with-inputs",
                                     "state": {
                                         "values": {
                                             "multiline": {
                                                 "mlvalue": {
                                                     "type": "plain_text_input",
                                                     "value": "This is my example inputted value"
                                                 }
                                             },
                                             "target_channel": {
                                                 "target_select": {
                                                     "type": "conversations_select",
                                                     "selected_conversation": "C123B12DE"
                                                 }
                                             }
                                         }
                                     },
                                     "hash": "156663117.cd33ad1f",
                                     "response_urls": [
                                         {
                                             "block_id": "target_channel",
                                             "action_id": "target_select",
                                             "channel_id": "C123B12DE",
                                             "response_url": "https://hooks.slack.com/app/ABC12312/1234567890/A100B100C100d100"
                                         }
                                     ]
                                 }
                             }
                             """,
                             "\n",
                             ""
                           )

  # Made-up workflow token and interactivity pointer for the custom step
  # fixtures built by function_payload/1. Slack documents no example values;
  # workflow tokens start with xwfp- per
  # https://docs.slack.dev/authentication/tokens/
  @workflow_token "xwfp-0000000000-0000000000-made-up-workflow-token"
  @interactivity_pointer "5527141823.8534564800.0c2e9a1d7b5f4e3c8a6d9b1f0e2c4a7d"

  # Temporary capabilities and credentials of the documented examples.
  @secret_values [
    @doc_secret,
    @workflow_token,
    @interactivity_pointer,
    "xyzz0WbapA4vBCDEFasx0q6G",
    "398738663015.47445629121.803a0bc887a14d10d2c447fce8b6703c",
    "9s8d9as89d8as9d8as989",
    "12321423423.333649436676.d8c1bb837935619ccad0f624c448ffb3",
    "XXXXXXXXXXXXX",
    "944799105734.773906753841.38b5894552bdd4a780554ee59d1f3638",
    "Nj2rfC2hU8mAfgaJLemZgO7H",
    "13345224609.8534564800.6f8ab1f53e13d0cd15f96106292d5536",
    "hooks.slack.com"
  ]

  # SHA-256 of form_body(@block_actions_payload), computed outside Elixir with
  # Python's hashlib over "payload=" + urllib.parse.quote_plus(payload).
  @block_actions_body_sha256 "aac09e1413b720dc67518a696b504aed72f411934550bc2b6cacb46dbb7b15b7"

  describe "verify_delivery/4" do
    test "verifies Slack's documented signature example and then requires a payload field" do
      headers = %{
        "x-slack-request-timestamp" => @doc_timestamp,
        "x-slack-signature" => @doc_signature
      }

      assert :ok = Webhook.verify_signature(@doc_body, headers, @doc_secret, now: @doc_now)

      assert {:error, %Error.ProviderError{provider: :slack, reason: :missing_payload}} =
               Interactivity.verify_delivery(@doc_body, headers, @doc_secret, now: @doc_now)
    end

    test "returns a verified delivery for a signed block_actions form body" do
      body = form_body(@block_actions_payload)

      assert {:ok, %WebhookDelivery{} = delivery} =
               Interactivity.verify_delivery(body, signed_headers(body), @doc_secret,
                 now: @doc_now
               )

      assert %WebhookDelivery{
               provider: :slack,
               signature_state: :verified,
               delivery_id: @block_actions_body_sha256,
               duplicate?: false,
               event: "block_actions",
               metadata: %{team_id: "T9TK3CUKW", api_app_id: "AABA1ABCD"},
               normalized_signal: nil
             } = delivery

      assert %{
               "type" => "block_actions",
               "user" => %{"id" => "UA8RXUSPL"},
               "message" => %{"text" => "This content can't be displayed."},
               "actions" => [%{"action_id" => "WaXA", "value" => "click_me_123"}]
             } = delivery.payload
    end

    test "sets team_id to nil when an org-wide install sends a null team" do
      # The property table of
      # https://docs.slack.dev/reference/interaction-payloads/block_actions-payload
      # says team is null if the app is org-installed. The documented payload
      # is changed only in that field.
      json =
        String.replace(
          @block_actions_payload,
          ~r/"team": \{[^}]*\}/,
          ~S("team": null),
          global: false
        )

      assert json =~ ~S("team": null,)

      assert {:ok,
              %WebhookDelivery{
                event: "block_actions",
                metadata: %{team_id: nil, api_app_id: "AABA1ABCD"},
                payload: %{"team" => nil}
              }} = verify(form_body(json))
    end

    test "marks byte-identical redelivery as duplicate and separates a one-byte change" do
      body = form_body(@block_actions_payload)

      assert {:ok, %WebhookDelivery{delivery_id: @block_actions_body_sha256, duplicate?: true}} =
               Interactivity.verify_delivery(body, signed_headers(body), @doc_secret,
                 now: @doc_now,
                 seen_delivery_ids: [@block_actions_body_sha256]
               )

      # One byte changed from the documented payload: "click_me_123" -> "click_me_124".
      changed = String.replace(body, "click_me_123", "click_me_124")
      assert byte_size(changed) == byte_size(body)

      assert {:ok, %WebhookDelivery{delivery_id: changed_id, duplicate?: false}} =
               Interactivity.verify_delivery(changed, signed_headers(changed), @doc_secret,
                 now: @doc_now,
                 seen_delivery_ids: [@block_actions_body_sha256]
               )

      assert changed_id =~ ~r/\A[0-9a-f]{64}\z/
      refute changed_id == @block_actions_body_sha256
    end

    test "rejects bad signatures with the existing auth error" do
      body = form_body(@block_actions_payload)
      changed = String.replace(body, "click_me_123", "click_me_124")

      for {request_body, headers} <- [
            {changed, signed_headers(body)},
            {body, signed_headers(body, secret: "another-signing-secret")},
            {body, Map.delete(signed_headers(body), "x-slack-signature")},
            {body, Map.put(signed_headers(body), "x-slack-signature", "v0=")}
          ] do
        assert {:error, %Error.AuthError{reason: :invalid_signature}} =
                 Interactivity.verify_delivery(request_body, headers, @doc_secret, now: @doc_now)
      end
    end

    test "rejects missing and stale timestamps with the existing auth errors" do
      body = form_body(@block_actions_payload)
      headers = signed_headers(body)

      assert {:error, %Error.AuthError{reason: :missing_timestamp}} =
               Interactivity.verify_delivery(
                 body,
                 Map.delete(headers, "x-slack-request-timestamp"),
                 @doc_secret,
                 now: @doc_now
               )

      for now <- [@doc_now + 301, @doc_now - 301] do
        assert {:error, %Error.AuthError{reason: :stale_timestamp}} =
                 Interactivity.verify_delivery(body, headers, @doc_secret, now: now)
      end

      for now <- [@doc_now + 300, @doc_now - 300] do
        assert {:ok, %WebhookDelivery{}} =
                 Interactivity.verify_delivery(body, headers, @doc_secret, now: now)
      end
    end

    test "rejects a missing signing secret with the existing auth error" do
      body = form_body(@block_actions_payload)

      for secret <- [nil, ""] do
        assert {:error, %Error.AuthError{reason: :missing_signing_secret}} =
                 Interactivity.verify_delivery(body, signed_headers(body), secret, now: @doc_now)
      end
    end
  end

  describe "payload type dispatch" do
    test "returns unsupported types as verified deliveries without a signal or HTTP request" do
      attach_http_probe()

      for {json, event, team_id, api_app_id} <- [
            {@shortcut_payload, "shortcut", "TXXXXXXXX", nil},
            {@message_action_payload, "message_action", "T0MJRM1A7", nil},
            {@block_actions_payload, "block_actions", "T9TK3CUKW", "AABA1ABCD"}
          ] do
        assert {:ok,
                %WebhookDelivery{
                  signature_state: :verified,
                  event: ^event,
                  normalized_signal: nil,
                  metadata: %{team_id: ^team_id, api_app_id: ^api_app_id}
                }} = verify(form_body(json), callback_ids: ["shortcut_create_task"])
      end

      refute_received {:http_request, _host}
    end

    test "Normalizer.normalize_signal/3 rejects types without a normalizer" do
      {:ok, %WebhookDelivery{payload: payload}} = verify(form_body(@shortcut_payload))

      for type <- ["shortcut", "message_action", "block_actions", "view_submission", nil] do
        assert {:error,
                %Error.ProviderError{
                  provider: :slack,
                  reason: :unsupported_event,
                  details: %{type: ^type}
                }} =
                 Normalizer.normalize_signal(type, payload,
                   api_app_id: "AABA1ABCD",
                   callback_ids: ["shortcut_create_task"]
                 )
      end
    end
  end

  describe "verify_delivery/4 temporary capabilities" do
    test "drops token, response_url and trigger_id and keeps the raw body out" do
      for {json, event} <- [
            {@block_actions_payload, "block_actions"},
            {@shortcut_payload, "shortcut"},
            {@message_action_payload, "message_action"}
          ] do
        body = form_body(json)

        assert {:ok, %WebhookDelivery{event: ^event} = delivery} = verify(body)

        refute Map.has_key?(delivery.payload, "token")
        refute Map.has_key?(delivery.payload, "response_url")
        refute Map.has_key?(delivery.payload, "trigger_id")
        assert %{"team" => %{"id" => _team}, "user" => %{"id" => _user}} = delivery.payload

        refute_secrets(delivery.payload, body)
        refute_secrets(WebhookDelivery.to_public_map(delivery), body)
        refute_secrets(inspect(delivery, limit: :infinity, printable_limit: :infinity), body)
      end
    end

    test "drops view_submission response_urls at the top level and under view" do
      # The documented example keeps response_urls under view; the second body
      # moves them to the top level, where the property table lists them.
      documented = Jason.decode!(@view_submission_payload)
      {response_urls, view} = Map.pop!(documented["view"], "response_urls")

      top_level =
        documented
        |> Map.put("view", view)
        |> Map.put("response_urls", response_urls)
        |> Jason.encode!()

      for json <- [@view_submission_payload, top_level] do
        body = form_body(json)

        assert {:ok, %WebhookDelivery{event: "view_submission"} = delivery} = verify(body)

        refute Map.has_key?(delivery.payload, "response_urls")
        assert %{"view" => delivered_view} = delivery.payload
        refute Map.has_key?(delivered_view, "response_urls")

        assert %{
                 "callback_id" => "modal-with-inputs",
                 "private_metadata" => "shhh-its-secret",
                 "state" => %{
                   "values" => %{
                     "target_channel" => %{
                       "target_select" => %{"selected_conversation" => "C123B12DE"}
                     }
                   }
                 }
               } = delivered_view

        refute_secrets(delivery.payload, body)
        refute_secrets(WebhookDelivery.to_public_map(delivery), body)
        refute_secrets(inspect(delivery, limit: :infinity, printable_limit: :infinity), body)
      end
    end

    test "drops the workflow token and interactivity pointer of custom step interactions" do
      for {json, event} <- [
            {function_payload(@block_actions_payload), "block_actions"},
            {function_payload(@view_submission_payload), "view_submission"}
          ] do
        body = form_body(json)

        assert {:ok, %WebhookDelivery{event: ^event} = delivery} = verify(body)

        refute Map.has_key?(delivery.payload, "bot_access_token")

        assert %{
                 "interactivity" => interactivity,
                 "function_data" => %{
                   "execution_id" => "Fx0000000001",
                   "function" => %{"callback_id" => "approve_request"}
                 }
               } = delivery.payload

        assert interactivity == %{"interactor" => %{"secret" => "made-up", "id" => "U0000001"}}

        refute_secrets(delivery.payload, body)
        refute_secrets(WebhookDelivery.to_public_map(delivery), body)
        refute_secrets(inspect(delivery, limit: :infinity, printable_limit: :infinity), body)
      end
    end

    test "keeps credentials, temporary capabilities and the raw body out of errors" do
      block_actions = form_body(@block_actions_payload)
      duplicate = block_actions <> "&" <> block_actions
      truncated = form_body(String.slice(@block_actions_payload, 0, 900))
      array = form_body("[" <> @message_action_payload <> "]")

      doc_headers = %{
        "x-slack-request-timestamp" => @doc_timestamp,
        "x-slack-signature" => @doc_signature
      }

      cases = [
        {@doc_body,
         Interactivity.verify_delivery(@doc_body, doc_headers, @doc_secret, now: @doc_now)},
        {duplicate, verify(duplicate)},
        {truncated, verify(truncated)},
        {array, verify(array)},
        {block_actions, verify(block_actions, max_body_bytes: 100)},
        {block_actions,
         Interactivity.verify_delivery(block_actions, doc_headers, @doc_secret, now: @doc_now)},
        {block_actions,
         Interactivity.verify_delivery(block_actions, signed_headers(block_actions), nil,
           now: @doc_now
         )}
      ]

      for {body, result} <- cases do
        assert {:error, error} = result
        refute_secrets(error, body)
        refute_secrets(Error.to_map(error), body)
        refute_secrets(Exception.message(error), body)
      end
    end
  end

  # The documented payload is padded with "+" (form-encoded spaces, JSON
  # whitespace after the object) to reach an exact body size.
  describe "verify_delivery/4 body size" do
    test "verifies a body of exactly 256 KiB and rejects one byte more before HMAC" do
      exact = pad_to(form_body(@block_actions_payload), 262_144)
      over = exact <> "+"

      assert {:ok, %WebhookDelivery{event: "block_actions"}} = verify(exact)

      assert {:error, %Error.AuthError{reason: :invalid_signature}} =
               Interactivity.verify_delivery(exact, signed_headers(over), @doc_secret,
                 now: @doc_now
               )

      assert_too_large(over, 262_144, [])
    end

    test "applies the 256 KiB default when :max_body_bytes is nil" do
      exact = pad_to(form_body(@block_actions_payload), 262_144)

      assert {:ok, %WebhookDelivery{event: "block_actions"}} =
               verify(exact, max_body_bytes: nil)

      assert_too_large(exact <> "+", 262_144, max_body_bytes: nil)
    end

    test "applies an overridden :max_body_bytes" do
      body = form_body(@block_actions_payload)
      max = byte_size(body)

      assert {:ok, %WebhookDelivery{event: "block_actions"}} = verify(body, max_body_bytes: max)
      assert_too_large(body, max - 1, max_body_bytes: max - 1)

      larger = pad_to(body, 262_145)
      assert {:ok, %WebhookDelivery{}} = verify(larger, max_body_bytes: 262_145)
      assert_too_large(larger, 262_144, [])
    end
  end

  # The parser cases start from the documented block_actions payload. Each
  # change to it is named in the test that makes it.
  describe "verify_delivery/4 form body" do
    test "keeps Unicode, newlines and literal plus signs of the payload" do
      payload =
        @block_actions_payload
        |> String.replace(
          ~S("text": "This content can't be displayed."),
          ~S("text": "Grüße, Zoë 確認 👍\nzweite Zeile")
        )
        |> String.replace(~S("value": "click_me_123"), ~S("value": "1+1=2 & more"))

      body = form_body(payload)
      # UTF-8 escapes, raw newlines between JSON tokens, the JSON \n escape
      # and an escaped literal plus sign.
      assert body =~ "Gr%C3%BC%C3%9Fe"
      assert body =~ "%7B%0A"
      assert body =~ "%5Cnzweite"
      assert body =~ "1%2B1%3D2+%26+more"

      assert {:ok, %WebhookDelivery{payload: decoded}} = verify(body)

      assert %{
               "message" => %{"text" => "Grüße, Zoë 確認 👍\nzweite Zeile"},
               "actions" => [%{"value" => "1+1=2 & more"}]
             } = decoded
    end

    test "decodes plus signs and %20 as spaces and accepts lowercase percent escapes" do
      plus_body = form_body(@block_actions_payload)

      percent_body =
        "payload=" <>
          (@block_actions_payload
           |> URI.encode(&URI.char_unreserved?/1)
           |> String.replace(~r/%[0-9A-F]{2}/, &String.downcase/1))

      assert plus_body =~ "This+content+can%27t+be+displayed."
      assert percent_body =~ "This%20content%20can%27t%20be%20displayed."
      assert percent_body =~ "%7b%0a"

      assert {:ok, %WebhookDelivery{payload: from_plus}} = verify(plus_body)
      assert {:ok, %WebhookDelivery{payload: from_percent}} = verify(percent_body)

      assert %{"message" => %{"text" => "This content can't be displayed."}} = from_plus
      assert from_percent == from_plus
    end

    test "ignores form fields other than payload" do
      body = form_body(@block_actions_payload) <> "&ssl_check=1"

      assert {:ok, %WebhookDelivery{event: "block_actions"}} = verify(body)
    end

    test "rejects a body without a payload field" do
      for body <- ["", "ssl_check=1", "payloads=" <> URI.encode_www_form(@block_actions_payload)] do
        assert {:error, %Error.ProviderError{provider: :slack, reason: :missing_payload}} =
                 verify(body)
      end
    end

    test "rejects a body with more than one payload field" do
      single = form_body(@block_actions_payload)

      for body <- [single <> "&" <> single, single <> "&payload=", "payload=&" <> single] do
        assert {:error, %Error.ProviderError{provider: :slack, reason: :duplicate_payload}} =
                 verify(body)
      end
    end

    test "rejects payload values that are not valid JSON" do
      bodies = [
        # Truncated documented payload.
        form_body(String.slice(@block_actions_payload, 0, 200)),
        "payload=",
        # Malformed percent escape, kept literally by the form decoder.
        "payload=%7B%ZZ%7D",
        # Invalid UTF-8 (C3 28) inside the message text.
        "payload=" <>
          String.replace(
            URI.encode_www_form(@block_actions_payload),
            "This+content",
            "%C3%28+content"
          ),
        # Raw newline inside a JSON string instead of the \n escape.
        form_body(String.replace(@block_actions_payload, "can't be", "can't\nbe"))
      ]

      for body <- bodies do
        assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_payload}} =
                 verify(body)
      end
    end

    test "rejects JSON payload values that are not objects" do
      for json <- ["[" <> @block_actions_payload <> "]", ~S("block_actions"), "42", "null"] do
        assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_payload}} =
                 verify(form_body(json))
      end
    end

    test "rejects a payload type that is not a string" do
      # Documented payload with "type" changed to a number.
      json = String.replace(@block_actions_payload, ~S("type": "block_actions"), ~S("type": 5))

      assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_payload}} =
               verify(form_body(json))
    end
  end

  defp verify(body, opts \\ []) do
    Interactivity.verify_delivery(
      body,
      signed_headers(body),
      @doc_secret,
      Keyword.put_new(opts, :now, @doc_now)
    )
  end

  # A validly signed oversized body fails with :body_too_large, and so does the
  # same body without a signing secret: the bound is checked before the HMAC.
  defp assert_too_large(body, expected_max, opts) do
    opts = Keyword.put(opts, :now, @doc_now)

    for secret <- [@doc_secret, nil] do
      assert {:error,
              %Error.ProviderError{
                provider: :slack,
                reason: :body_too_large,
                details: %{max_body_bytes: ^expected_max}
              }} = Interactivity.verify_delivery(body, signed_headers(body), secret, opts)
    end
  end

  # Req sends every HTTP request through Finch, which emits this event in the
  # calling process.
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

  defp refute_secrets(value, raw_body) do
    text =
      if is_binary(value),
        do: value,
        else: inspect(value, limit: :infinity, printable_limit: :infinity)

    for secret <- [raw_body, binary_part(raw_body, 0, 40) | @secret_values] do
      refute String.contains?(text, secret), "found #{inspect(secret)} in #{text}"
    end
  end

  defp pad_to(body, size), do: body <> String.duplicate("+", size - byte_size(body))

  defp form_body(payload_json), do: "payload=" <> URI.encode_www_form(payload_json)

  # Turns a documented payload into one from a custom step (function). The
  # property tables of
  # https://docs.slack.dev/reference/interaction-payloads/block_actions-payload
  # and
  # https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload
  # list function_data, interactivity and bot_access_token only for functions
  # and token, response_url and response_urls only for other apps. Neither page
  # shows a function example, so the added values are made up in the shape of
  # the Bolt JS payload types and the Deno Slack SDK interactivity object.
  defp function_payload(json) do
    payload = json |> Jason.decode!() |> Map.drop(["token", "response_url"])

    payload
    |> Map.replace_lazy("view", &Map.delete(&1, "response_urls"))
    |> Map.merge(%{
      "function_data" => %{
        "execution_id" => "Fx0000000001",
        "function" => %{"callback_id" => "approve_request"},
        "inputs" => %{"requester" => "U0000001"}
      },
      "interactivity" => %{
        "interactor" => %{"secret" => "made-up", "id" => "U0000001"},
        "interactivity_pointer" => @interactivity_pointer
      },
      "bot_access_token" => @workflow_token
    })
    |> Jason.encode!()
  end

  defp signed_headers(body, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp, @doc_timestamp)
    secret = Keyword.get(opts, :secret, @doc_secret)

    %{
      "content-type" => "application/x-www-form-urlencoded",
      "x-slack-request-timestamp" => timestamp,
      "x-slack-signature" => slack_signature(secret, timestamp, body)
    }
  end

  defp slack_signature(secret, timestamp, body) do
    digest =
      :hmac
      |> :crypto.mac(:sha256, secret, "v0:#{timestamp}:#{body}")
      |> Base.encode16(case: :lower)

    "v0=" <> digest
  end
end
