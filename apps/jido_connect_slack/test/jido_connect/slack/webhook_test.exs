defmodule Jido.Connect.Slack.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.Webhook

  test "verifies valid Slack signature" do
    body = ~s({"type":"event_callback"})
    timestamp = "1700000000"
    signature = slack_signature("secret", timestamp, body)

    assert :ok =
             Webhook.verify_signature(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000
             )
  end

  test "verifies signed JSON requests" do
    body =
      Jason.encode!(%{
        type: "event_callback",
        team_id: "T123",
        event_id: "Ev123",
        event: %{
          type: "app_mention",
          channel: "C123",
          user: "U123",
          text: "<@U999> hello",
          ts: "1700000000.000100"
        }
      })

    timestamp = "1700000000"
    signature = slack_signature("secret", timestamp, body)

    assert {:ok, %{"type" => "event_callback"}} =
             Webhook.verify_request(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000
             )

    assert {:ok,
            %WebhookDelivery{
              provider: :slack,
              delivery_id: "Ev123",
              event: "app_mention",
              signature_state: :verified,
              duplicate?: true,
              payload: %{"type" => "event_callback"},
              normalized_signal: %{
                team_id: "T123",
                event_id: "Ev123",
                channel: "C123",
                text: "<@U999> hello",
                delivery: %{
                  provider: :slack,
                  event: "app_mention",
                  id: "Ev123",
                  duplicate?: true,
                  received_at: %DateTime{}
                }
              }
            }} =
             Webhook.verify_delivery(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000,
               seen_delivery_ids: ["Ev123"]
             )
  end

  test "rejects signed Slack JSON that is not an object" do
    timestamp = "1700000000"

    for body <- ["42", "[1,2]"] do
      headers = %{
        "x-slack-signature" => slack_signature("secret", timestamp, body),
        "x-slack-request-timestamp" => timestamp
      }

      assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_payload}} =
               Webhook.verify_delivery(body, headers, "secret", now: 1_700_000_000)
    end
  end

  test "rejects missing secret, stale timestamp, and invalid signature" do
    body = "{}"
    headers = %{"x-slack-signature" => "v0=bad", "x-slack-request-timestamp" => "1700000000"}

    assert {:error, %Error.AuthError{reason: :missing_signing_secret}} =
             Webhook.verify_signature(body, headers, nil, now: 1_700_000_000)

    assert {:error, %Error.AuthError{reason: :stale_timestamp}} =
             Webhook.verify_signature(body, headers, "secret", now: 1_700_001_000)

    assert {:error, %Error.AuthError{reason: :invalid_signature}} =
             Webhook.verify_signature(body, headers, "secret", now: 1_700_000_000)

    assert {:error, %Error.AuthError{reason: :missing_timestamp}} =
             Webhook.verify_signature(body, %{"x-slack-signature" => "v0=bad"}, "secret",
               now: 1_700_000_000
             )

    assert {:error, %Error.AuthError{reason: :invalid_timestamp}} =
             Webhook.verify_signature(
               body,
               %{"x-slack-signature" => "v0=bad", "x-slack-request-timestamp" => "nope"},
               "secret",
               now: 1_700_000_000
             )
  end

  test "returns url verification challenge" do
    assert {:ok, "challenge"} =
             Webhook.url_verification_challenge(%{
               "type" => "url_verification",
               "challenge" => "challenge"
             })

    assert {:error, %Error.ProviderError{provider: :slack, reason: :not_url_verification}} =
             Webhook.url_verification_challenge(%{"type" => "event_callback"})
  end

  test "normalizes app mention events" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev123",
      "event" => %{
        "type" => "app_mention",
        "channel" => "C123",
        "channel_type" => "channel",
        "user" => "U123",
        "text" => "<@U999> hello",
        "ts" => "1700000000.000100",
        "thread_ts" => "1700000000.000000"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev123",
              channel: "C123",
              channel_type: "channel",
              user: "U123",
              text: "<@U999> hello",
              ts: "1700000000.000100",
              thread_ts: "1700000000.000000"
            }} = Webhook.normalize_signal("app_mention", payload)

    assert {:ok, %{channel: "C123"}} = Webhook.normalize_event(payload)

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_event}} =
             Webhook.normalize_signal("unknown_event", %{
               "type" => "event_callback",
               "event" => %{"type" => "unknown_event"}
             })
  end

  test "normalizes public channel message events and rejects subtypes" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev456",
      "event" => %{
        "type" => "message",
        "channel" => "C123",
        "channel_type" => "channel",
        "user" => "U123",
        "text" => "hello",
        "ts" => "1700000000.000200",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000200"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev456",
              channel: "C123",
              channel_type: "channel",
              user: "U123",
              text: "hello",
              ts: "1700000000.000200",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000200"
            }} = Webhook.normalize_signal("message", payload)

    assert {:ok, %{channel: "C123"}} = Webhook.normalize_signal("message.channels", payload)
    assert {:ok, %{channel: "C123"}} = Webhook.normalize_event(payload)

    subtype_payload = put_in(payload, ["event", "subtype"], "message_changed")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_message_subtype}} =
             Webhook.normalize_signal("message", subtype_payload)

    im_payload = put_in(payload, ["event", "channel_type"], "im")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.channels", im_payload)
  end

  test "normalizes private channel message events and rejects other channel types" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev789",
      "event" => %{
        "type" => "message",
        "channel" => "G123",
        "channel_type" => "group",
        "user" => "U123",
        "text" => "private hello",
        "ts" => "1700000000.000300",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000300"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev789",
              channel: "G123",
              channel_type: "group",
              user: "U123",
              text: "private hello",
              ts: "1700000000.000300",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000300"
            }} = Webhook.normalize_signal("message.groups", payload)

    assert {:ok, %{channel: "G123"}} = Webhook.normalize_signal("message", payload)
    assert {:ok, %{channel: "G123"}} = Webhook.normalize_event(payload)

    public_payload = put_in(payload, ["event", "channel_type"], "channel")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.groups", public_payload)
  end

  test "normalizes direct message events with user and conversation metadata" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev901",
      "event" => %{
        "type" => "message",
        "channel" => "D123",
        "channel_type" => "im",
        "user" => "U123",
        "user_team" => "T123",
        "source_team" => "T123",
        "text" => "direct hello",
        "ts" => "1700000000.000400",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000400"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev901",
              channel: "D123",
              channel_type: "im",
              user: "U123",
              user_team: "T123",
              source_team: "T123",
              text: "direct hello",
              ts: "1700000000.000400",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000400",
              sender: %{id: "U123", team_id: "T123"},
              conversation: %{id: "D123", type: "im"}
            }} = Webhook.normalize_signal("message.im", payload)

    assert {:ok, %{channel: "D123", conversation: %{type: "im"}}} =
             Webhook.normalize_signal("message", payload)

    assert {:ok, %{channel: "D123", conversation: %{type: "im"}}} =
             Webhook.normalize_event(payload)

    group_payload = put_in(payload, ["event", "channel_type"], "group")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.im", group_payload)
  end

  test "normalizes multi-person direct message events with user and conversation metadata" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev902",
      "event" => %{
        "type" => "message",
        "channel" => "GMP123",
        "channel_type" => "mpim",
        "user" => "U123",
        "user_team" => "T123",
        "source_team" => "T456",
        "text" => "group direct hello",
        "ts" => "1700000000.000500",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000500"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev902",
              channel: "GMP123",
              channel_type: "mpim",
              user: "U123",
              user_team: "T123",
              source_team: "T456",
              text: "group direct hello",
              ts: "1700000000.000500",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000500",
              sender: %{id: "U123", team_id: "T123"},
              conversation: %{id: "GMP123", type: "mpim"}
            }} = Webhook.normalize_signal("message.mpim", payload)

    assert {:ok, %{channel: "GMP123", conversation: %{type: "mpim"}}} =
             Webhook.normalize_signal("message", payload)

    im_payload = put_in(payload, ["event", "channel_type"], "im")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :unsupported_channel_type}} =
             Webhook.normalize_signal("message.mpim", im_payload)
  end

  test "normalizes thread reply message events and rejects thread roots" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev903",
      "event" => %{
        "type" => "message",
        "channel" => "C123",
        "channel_type" => "channel",
        "user" => "U123",
        "text" => "thread reply",
        "ts" => "1700000000.000600",
        "thread_ts" => "1700000000.000100",
        "event_ts" => "1700000000.000600"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev903",
              channel: "C123",
              channel_type: "channel",
              user: "U123",
              text: "thread reply",
              ts: "1700000000.000600",
              thread_ts: "1700000000.000100",
              event_ts: "1700000000.000600"
            }} = Webhook.normalize_signal("message.thread_reply", payload)

    root_payload = put_in(payload, ["event", "ts"], "1700000000.000100")

    assert {:error, %Error.ProviderError{provider: :slack, reason: :thread_root_message}} =
             Webhook.normalize_signal("message.thread_reply", root_payload)

    unthreaded_payload = update_in(payload, ["event"], &Map.delete(&1, "thread_ts"))

    assert {:error, %Error.ProviderError{provider: :slack, reason: :not_thread_reply}} =
             Webhook.normalize_signal("message.thread_reply", unthreaded_payload)
  end

  test "normalizes reaction added events with item metadata and actor identity" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev904",
      "event" => %{
        "type" => "reaction_added",
        "user" => "U123",
        "reaction" => "thumbsup",
        "item_user" => "U456",
        "item" => %{
          "type" => "message",
          "channel" => "C123",
          "ts" => "1700000000.000700"
        },
        "event_ts" => "1700000000.000800"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev904",
              user: "U123",
              reaction: "thumbsup",
              item_user: "U456",
              item: %{
                "type" => "message",
                "channel" => "C123",
                "ts" => "1700000000.000700"
              },
              item_type: "message",
              channel: "C123",
              ts: "1700000000.000700",
              event_ts: "1700000000.000800",
              actor: %{id: "U123", team_id: "T123"},
              item_owner: %{id: "U456", team_id: "T123"}
            }} = Webhook.normalize_signal("reaction_added", payload)

    assert {:ok, %{reaction: "thumbsup", item_type: "message"}} =
             Webhook.normalize_event(payload)

    file_payload =
      put_in(payload, ["event", "item"], %{
        "type" => "file_comment",
        "file" => "F123",
        "file_comment" => "Fc123"
      })

    assert {:ok,
            %{
              item_type: "file_comment",
              file: "F123",
              file_comment: "Fc123"
            }} = Webhook.normalize_signal("reaction_added", file_payload)
  end

  test "normalizes reaction removed events with item metadata and actor identity" do
    payload = %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => "Ev905",
      "event" => %{
        "type" => "reaction_removed",
        "user" => "U123",
        "reaction" => "thumbsup",
        "item_user" => "U456",
        "item" => %{
          "type" => "message",
          "channel" => "C123",
          "ts" => "1700000000.000700"
        },
        "event_ts" => "1700000000.000900"
      }
    }

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev905",
              user: "U123",
              reaction: "thumbsup",
              item_user: "U456",
              item: %{
                "type" => "message",
                "channel" => "C123",
                "ts" => "1700000000.000700"
              },
              item_type: "message",
              channel: "C123",
              ts: "1700000000.000700",
              event_ts: "1700000000.000900",
              actor: %{id: "U123", team_id: "T123"},
              item_owner: %{id: "U456", team_id: "T123"}
            }} = Webhook.normalize_signal("reaction_removed", payload)

    assert {:ok, %{reaction: "thumbsup", item_type: "message"}} =
             Webhook.normalize_event(payload)
  end

  test "normalizes channel created events with channel metadata" do
    payload =
      channel_event_payload("channel_created", "Ev906", %{
        "channel" => %{
          "id" => "C123",
          "name" => "project",
          "created" => 1_700_000_000,
          "creator" => "U123"
        }
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev906",
              channel_id: "C123",
              channel: %{
                "id" => "C123",
                "name" => "project",
                "created" => 1_700_000_000,
                "creator" => "U123"
              },
              actor: %{id: "U123", team_id: "T123"}
            }} = Webhook.normalize_signal("channel_created", payload)

    assert {:ok, %{channel_id: "C123"}} = Webhook.normalize_event(payload)
  end

  test "normalizes channel rename events with channel metadata" do
    payload =
      channel_event_payload("channel_rename", "Ev907", %{
        "channel" => %{"id" => "C123", "name" => "project-renamed", "created" => 1_700_000_000},
        "event_ts" => "1700000000.001000"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev907",
              channel_id: "C123",
              channel: %{"id" => "C123", "name" => "project-renamed", "created" => 1_700_000_000},
              event_ts: "1700000000.001000"
            }} = Webhook.normalize_signal("channel_rename", payload)
  end

  test "normalizes channel archive and unarchive events with actor metadata" do
    archive_payload =
      channel_event_payload("channel_archive", "Ev908", %{
        "channel" => "C123",
        "user" => "U123",
        "event_ts" => "1700000000.001100"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev908",
              channel_id: "C123",
              user: "U123",
              event_ts: "1700000000.001100",
              actor: %{id: "U123", team_id: "T123"}
            }} = Webhook.normalize_signal("channel_archive", archive_payload)

    assert {:ok, signal} = Webhook.normalize_event(archive_payload)
    refute Map.has_key?(signal, :channel)

    unarchive_payload =
      channel_event_payload("channel_unarchive", "Ev909", %{
        "channel" => "C123",
        "user" => "U456",
        "event_ts" => "1700000000.001200"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev909",
              channel_id: "C123",
              user: "U456",
              event_ts: "1700000000.001200",
              actor: %{id: "U456", team_id: "T123"}
            }} = Webhook.normalize_signal("channel_unarchive", unarchive_payload)
  end

  test "normalizes member joined channel events with membership metadata" do
    payload =
      channel_event_payload("member_joined_channel", "Ev910", %{
        "user" => "U123",
        "channel" => "C123",
        "channel_type" => "C",
        "team" => "T123",
        "inviter" => "U456",
        "event_ts" => "1700000000.001300"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev910",
              channel_id: "C123",
              channel: "C123",
              channel_type: "C",
              user: "U123",
              inviter: "U456",
              event_ts: "1700000000.001300",
              actor: %{id: "U123", team_id: "T123"},
              inviter_user: %{id: "U456", team_id: "T123"}
            }} = Webhook.normalize_signal("member_joined_channel", payload)

    assert {:ok, %{channel_id: "C123", user: "U123"}} = Webhook.normalize_event(payload)
  end

  test "normalizes member left channel events with membership metadata" do
    payload =
      channel_event_payload("member_left_channel", "Ev911", %{
        "user" => "U123",
        "channel" => "C123",
        "channel_type" => "C",
        "team" => "T123",
        "event_ts" => "1700000000.001400"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev911",
              channel_id: "C123",
              channel: "C123",
              channel_type: "C",
              user: "U123",
              event_ts: "1700000000.001400",
              actor: %{id: "U123", team_id: "T123"}
            }} = Webhook.normalize_signal("member_left_channel", payload)

    assert {:ok, signal} = Webhook.normalize_event(payload)
    refute Map.has_key?(signal, :inviter)
    refute Map.has_key?(signal, :inviter_user)
  end

  test "normalizes file created events with file metadata" do
    payload = file_event_payload("file_created", "Ev912", %{"user_id" => "U123"})

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev912",
              file_id: "F123",
              file: %{"id" => "F123"},
              user_id: "U123",
              actor: %{id: "U123", team_id: "T123"}
            }} = Webhook.normalize_signal("file_created", payload)

    assert {:ok, %{file_id: "F123"}} = Webhook.normalize_event(payload)
  end

  test "normalizes file shared events with channel and actor metadata" do
    payload =
      file_event_payload("file_shared", "Ev907", %{
        "channel_id" => "C123",
        "user_id" => "U123",
        "event_ts" => "1700000000.001000"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev907",
              file_id: "F123",
              file: %{"id" => "F123"},
              user_id: "U123",
              channel_id: "C123",
              event_ts: "1700000000.001000",
              actor: %{id: "U123", team_id: "T123"}
            }} = Webhook.normalize_signal("file_shared", payload)

    assert {:ok, %{channel_id: "C123"}} = Webhook.normalize_event(payload)
  end

  test "normalizes file public events" do
    payload = file_event_payload("file_public", "Ev908")

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev908",
              file_id: "F123",
              file: %{"id" => "F123"}
            }} = Webhook.normalize_signal("file_public", payload)
  end

  test "normalizes file deleted events without requiring embedded file metadata" do
    payload =
      file_event_payload("file_deleted", "Ev909", %{"event_ts" => "1700000000.001100"})
      |> update_in(["event"], &Map.delete(&1, "file"))

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev909",
              file_id: "F123",
              event_ts: "1700000000.001100"
            }} = Webhook.normalize_signal("file_deleted", payload)

    assert {:ok, signal} = Webhook.normalize_event(payload)
    refute Map.has_key?(signal, :file)
  end

  test "normalizes file change events" do
    payload =
      file_event_payload("file_change", "Ev910", %{
        "event_ts" => "1700000000.001200",
        "file" => %{"id" => "F123", "name" => "report.pdf"}
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev910",
              file_id: "F123",
              file: %{"id" => "F123", "name" => "report.pdf"},
              event_ts: "1700000000.001200"
            }} = Webhook.normalize_signal("file_change", payload)
  end

  test "normalizes app uninstalled events" do
    payload =
      app_lifecycle_payload("app_uninstalled", "Ev916", %{}, %{
        "authorizations" => [
          %{
            "team_id" => "T123",
            "user_id" => "U123",
            "is_bot" => false,
            "is_enterprise_install" => false
          }
        ]
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev916",
              api_app_id: "A123",
              event_time: 1_700_000_000,
              authorizations: [
                %{
                  "team_id" => "T123",
                  "user_id" => "U123",
                  "is_bot" => false,
                  "is_enterprise_install" => false
                }
              ]
            }} = Webhook.normalize_signal("app_uninstalled", payload)

    assert {:ok, %{api_app_id: "A123"}} = Webhook.normalize_event(payload)
  end

  test "normalizes tokens revoked events without exposing token material" do
    payload =
      app_lifecycle_payload("tokens_revoked", "Ev917", %{
        "tokens" => %{
          "oauth" => ["U123"],
          "bot" => ["U999"]
        }
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev917",
              api_app_id: "A123",
              event_time: 1_700_000_000,
              tokens: %{"oauth" => ["U123"], "bot" => ["U999"]},
              oauth_user_ids: ["U123"],
              bot_user_ids: ["U999"]
            }} = Webhook.normalize_signal("tokens_revoked", payload)

    assert {:ok, %{oauth_user_ids: ["U123"], bot_user_ids: ["U999"]}} =
             Webhook.normalize_event(payload)
  end

  test "normalizes scope denied events conservatively" do
    payload =
      app_lifecycle_payload("scope_denied", "Ev918", %{
        "scopes" => ["channels:history"],
        "user" => "U123",
        "trigger_id" => "123.456",
        "event_ts" => "1700000000.001300"
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev918",
              api_app_id: "A123",
              event_time: 1_700_000_000,
              scopes: ["channels:history"],
              user: "U123",
              trigger_id: "123.456",
              event_ts: "1700000000.001300"
            }} = Webhook.normalize_signal("scope_denied", payload)

    assert {:ok, %{scopes: ["channels:history"]}} = Webhook.normalize_event(payload)
  end

  test "normalizes app home opened events with view metadata" do
    payload =
      app_lifecycle_payload("app_home_opened", "Ev919", %{
        "user" => "U123",
        "channel" => "D123",
        "tab" => "home",
        "event_ts" => "1700000000.001400",
        "view" => %{
          "id" => "V123",
          "team_id" => "T123",
          "type" => "home",
          "app_id" => "A123"
        }
      })

    assert {:ok,
            %{
              team_id: "T123",
              event_id: "Ev919",
              api_app_id: "A123",
              user: "U123",
              channel: "D123",
              tab: "home",
              event_ts: "1700000000.001400",
              view: %{"id" => "V123", "team_id" => "T123", "type" => "home", "app_id" => "A123"},
              actor: %{id: "U123", team_id: "T123"},
              conversation: %{id: "D123", type: "app_home", tab: "home"}
            }} = Webhook.normalize_signal("app_home_opened", payload)

    assert {:ok, %{conversation: %{type: "app_home"}}} = Webhook.normalize_event(payload)
  end

  test "invalid JSON payloads are provider errors" do
    body = "not json"
    timestamp = "1700000000"
    signature = slack_signature("secret", timestamp, body)

    assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_payload}} =
             Webhook.verify_request(
               body,
               %{
                 "x-slack-signature" => signature,
                 "x-slack-request-timestamp" => timestamp
               },
               "secret",
               now: 1_700_000_000
             )
  end

  defp slack_signature(secret, timestamp, body) do
    base = "v0:#{timestamp}:#{body}"

    signature =
      :hmac
      |> :crypto.mac(:sha256, secret, base)
      |> Base.encode16(case: :lower)

    "v0=#{signature}"
  end

  defp file_event_payload(type, event_id, event_attrs \\ %{}) do
    %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => event_id,
      "event" =>
        Map.merge(
          %{
            "type" => type,
            "file_id" => "F123",
            "file" => %{"id" => "F123"}
          },
          event_attrs
        )
    }
  end

  defp channel_event_payload(type, event_id, event_attrs) do
    %{
      "type" => "event_callback",
      "team_id" => "T123",
      "event_id" => event_id,
      "event" => Map.put(event_attrs, "type", type)
    }
  end

  defp app_lifecycle_payload(type, event_id, event_attrs, payload_attrs \\ %{}) do
    Map.merge(
      %{
        "type" => "event_callback",
        "team_id" => "T123",
        "api_app_id" => "A123",
        "event_id" => event_id,
        "event_time" => 1_700_000_000,
        "event" => Map.put(event_attrs, "type", type)
      },
      payload_attrs
    )
  end
end
