defmodule Jido.Connect.Gmail.PrivacyAuditTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"

  defmodule RecordedThreadClient do
    # Serves the recorded format=full conversation.
    def get_thread_content(%{thread_id: _thread_id}, "token"),
      do: {:ok, LiveSmoke.fixture!(:gmail, "thread_full_conversation")}
  end

  test "classifies every Gmail action and trigger privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(
      Gmail,
      [
        action("google.gmail.profile.get", :personal_data, :read, :none),
        action("google.gmail.labels.list", :personal_data, :read, :none),
        action("google.gmail.label.get", :personal_data, :read, :none),
        action("google.gmail.messages.list", :message_content, :read, :none,
          text_includes: ["metadata", "without fetching full message bodies"]
        ),
        action("google.gmail.message.get", :message_content, :read, :none,
          text_includes: ["message metadata", "no body data"]
        ),
        action("google.gmail.threads.list", :message_content, :read, :none,
          text_includes: ["metadata", "without fetching full message bodies"]
        ),
        action("google.gmail.thread.get", :message_content, :read, :none,
          text_includes: ["thread metadata", "no body data"]
        ),
        action("google.gmail.drafts.list", :message_content, :read, :none,
          text_includes: ["draft metadata", "without fetching raw"]
        ),
        action("google.gmail.draft.get", :message_content, :read, :none,
          text_includes: ["draft metadata", "no raw body data"]
        ),
        action("google.gmail.history.list", :message_content, :read, :none,
          text_includes: ["history records"]
        ),
        action("google.gmail.message.attachment.get", :message_content, :read, :none,
          text_includes: ["base64url-encoded", "attachment data"]
        ),
        action("google.gmail.message.content.get", :message_content, :read, :none,
          text_includes: [
            "full body text",
            "attachment manifest",
            "reads the message body",
            "does not fetch attachment bytes"
          ]
        ),
        action("google.gmail.thread.content.get", :message_content, :read, :none,
          text_includes: [
            "every message of a gmail thread",
            "sent replies",
            "full body text",
            "reads message bodies",
            "does not fetch attachment bytes"
          ]
        ),
        action("google.gmail.message.send", :message_content, :external_write, :required_for_ai,
          text_includes: ["send", "body content"]
        ),
        action("google.gmail.draft.create", :message_content, :write, :required_for_ai,
          text_includes: ["draft", "body content"]
        ),
        action("google.gmail.draft.update", :message_content, :write, :required_for_ai,
          text_includes: ["draft", "body content"]
        ),
        action("google.gmail.draft.send", :message_content, :external_write, :required_for_ai),
        action("google.gmail.draft.delete", :message_content, :destructive, :always),
        action("google.gmail.label.create", :personal_data, :write, :required_for_ai),
        action("google.gmail.label.update", :personal_data, :write, :required_for_ai),
        action("google.gmail.label.delete", :personal_data, :destructive, :always),
        action("google.gmail.message.labels.apply", :message_content, :write, :required_for_ai),
        action("google.gmail.messages.batch_modify", :message_content, :write, :required_for_ai),
        action("google.gmail.message.trash", :message_content, :destructive, :always),
        action("google.gmail.message.untrash", :message_content, :write, :required_for_ai),
        action("google.gmail.message.delete", :message_content, :destructive, :always),
        action("google.gmail.messages.batch_delete", :message_content, :destructive, :always),
        action("google.gmail.thread.modify", :message_content, :write, :required_for_ai),
        action("google.gmail.thread.trash", :message_content, :destructive, :always),
        action("google.gmail.thread.untrash", :message_content, :write, :required_for_ai),
        action("google.gmail.thread.delete", :message_content, :destructive, :always),
        action("google.gmail.watch.start", :personal_data, :write, :required_for_ai,
          text_includes: ["push notifications"]
        ),
        action("google.gmail.watch.stop", :personal_data, :write, :required_for_ai,
          text_includes: ["push notification delivery"]
        )
      ],
      [
        trigger("google.gmail.message.received", :message_content,
          text_includes: ["message", "received"]
        ),
        trigger("google.gmail.mailbox.changed", :personal_data,
          text_includes: ["cloud pub/sub", "history ids"]
        )
      ]
    )
  end

  test "normalizes Gmail message payloads without raw body leakage" do
    {:ok, message} =
      Normalizer.message(%{
        "id" => "msg123",
        "threadId" => "thread123",
        "raw" => "raw-secret",
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "body" => %{"size" => 99, "data" => "body-secret"},
          "parts" => [
            %{
              "mimeType" => "text/plain",
              "body" => %{"size" => 12, "data" => "part-secret"}
            }
          ]
        }
      })

    refute inspect(message) =~ "raw-secret"
    refute inspect(message) =~ "body-secret"
    refute inspect(message) =~ "part-secret"
    assert message.payload_summary.body_size == 99
    assert [%{body_size: 12}] = message.payload_summary.parts
  end

  test "content reads return text beyond 512 bytes whole and keep it out of logs and telemetry" do
    test_pid = self()
    handler_id = "gmail-content-privacy-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [[:jido, :connect, :invoke, :start], [:jido, :connect, :invoke, :stop]],
      fn event, _measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    Logger.put_process_level(self(), :debug)

    log =
      capture_log([level: :debug], fn ->
        assert {:ok, %{thread: %{messages: [_received, _sent, long]}}} =
                 Connect.invoke(
                   Gmail.integration(),
                   "google.gmail.thread.content.get",
                   %{thread_id: "thread"},
                   readonly_grant(RecordedThreadClient)
                 )

        send(test_pid, {:long_message, long})
      end)

    assert_received {:long_message, long}
    assert [%{size: 55_272, content: content}] = long.text_parts
    assert byte_size(content) == 55_272
    assert String.ends_with?(content, "Marker jcl-marker-conv-long-end.\r\n")

    refute log =~ "jcl-marker"
    refute log =~ "Danke. Anbei die Notizen"

    events = drain_telemetry()
    assert Enum.any?(events, &match?({:telemetry, [:jido, :connect, :invoke, :stop], _}, &1))

    for {:telemetry, _event, metadata} <- events do
      refute inspect(metadata, limit: :infinity, printable_limit: :infinity) =~ "jcl-marker"
    end
  end

  defp drain_telemetry(acc \\ []) do
    receive do
      {:telemetry, _event, _metadata} = message -> drain_telemetry([message | acc])
    after
      0 -> acc
    end
  end

  defp readonly_grant(client) do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: [@readonly_scope]
      })

    [
      context:
        Connect.Context.new!(%{
          tenant_id: "tenant_1",
          actor: %{id: "user_1", type: :user},
          connection: connection
        }),
      credential_lease:
        Connect.CredentialLease.new!(%{
          connection_id: "conn_1",
          provider: :google,
          profile: :user,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          fields: %{access_token: "token", gmail_client: client},
          scopes: [@readonly_scope]
        })
    ]
  end

  defp action(id, classification, risk, confirmation, opts \\ []) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end

  defp trigger(id, classification, opts) do
    %{
      id: id,
      classification: classification,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
