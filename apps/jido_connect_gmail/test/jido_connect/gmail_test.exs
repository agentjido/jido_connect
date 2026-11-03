defmodule Jido.Connect.GmailTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  @gmail_action_modules [
    Jido.Connect.Gmail.Actions.GetProfile,
    Jido.Connect.Gmail.Actions.ListLabels,
    Jido.Connect.Gmail.Actions.GetLabel,
    Jido.Connect.Gmail.Actions.ListMessages,
    Jido.Connect.Gmail.Actions.GetMessage,
    Jido.Connect.Gmail.Actions.ListThreads,
    Jido.Connect.Gmail.Actions.GetThread,
    Jido.Connect.Gmail.Actions.ListDrafts,
    Jido.Connect.Gmail.Actions.GetDraft,
    Jido.Connect.Gmail.Actions.ListHistory,
    Jido.Connect.Gmail.Actions.GetAttachment,
    Jido.Connect.Gmail.Actions.GetMessageContent,
    Jido.Connect.Gmail.Actions.GetThreadContent,
    Jido.Connect.Gmail.Actions.GetAttachmentContent,
    Jido.Connect.Gmail.Actions.SendMessage,
    Jido.Connect.Gmail.Actions.CreateDraft,
    Jido.Connect.Gmail.Actions.UpdateDraft,
    Jido.Connect.Gmail.Actions.SendDraft,
    Jido.Connect.Gmail.Actions.DeleteDraft,
    Jido.Connect.Gmail.Actions.CreateLabel,
    Jido.Connect.Gmail.Actions.UpdateLabel,
    Jido.Connect.Gmail.Actions.DeleteLabel,
    Jido.Connect.Gmail.Actions.ApplyMessageLabels,
    Jido.Connect.Gmail.Actions.BatchModifyMessages,
    Jido.Connect.Gmail.Actions.TrashMessage,
    Jido.Connect.Gmail.Actions.UntrashMessage,
    Jido.Connect.Gmail.Actions.DeleteMessage,
    Jido.Connect.Gmail.Actions.BatchDeleteMessages,
    Jido.Connect.Gmail.Actions.ModifyThread,
    Jido.Connect.Gmail.Actions.TrashThread,
    Jido.Connect.Gmail.Actions.UntrashThread,
    Jido.Connect.Gmail.Actions.DeleteThread,
    Jido.Connect.Gmail.Actions.StartWatch,
    Jido.Connect.Gmail.Actions.StopWatch
  ]

  @gmail_dsl_fragments [
    Jido.Connect.Gmail.Actions.Read,
    Jido.Connect.Gmail.Actions.Write,
    Jido.Connect.Gmail.Actions.Watch,
    Jido.Connect.Gmail.Triggers.Messages
  ]

  defmodule FakeGmailClient do
    def get_profile(%{}, "token") do
      {:ok,
       Gmail.Profile.new!(%{
         email_address: "user@example.com",
         messages_total: 10,
         threads_total: 5,
         history_id: "123"
       })}
    end

    def list_labels(%{}, "token") do
      {:ok,
       %{
         labels: [
           Gmail.Label.new!(%{
             label_id: "INBOX",
             name: "INBOX",
             type: "system"
           })
         ]
       }}
    end

    def get_label(%{label_id: "Label_123"}, "token") do
      {:ok,
       Gmail.Label.new!(%{
         label_id: "Label_123",
         name: "Customers",
         type: "user"
       })}
    end

    def list_messages(
          %{
            query: "from:sender@example.com",
            label_ids: ["INBOX"],
            page_size: 25,
            include_spam_trash: false
          },
          "token"
        ) do
      {:ok,
       %{
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             label_ids: ["INBOX"],
             snippet: "Budget update"
           })
         ],
         next_page_token: "next",
         result_size_estimate: 1
       }}
    end

    def get_message(%{message_id: "msg123", metadata_headers: ["From", "Subject"]}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "msg123",
         thread_id: "thread123",
         label_ids: ["INBOX"],
         snippet: "Budget update",
         headers: [
           %{name: "From", value: "sender@example.com"},
           %{name: "Subject", value: "Budget"}
         ]
       })}
    end

    def list_threads(
          %{
            query: "label:inbox",
            label_ids: ["INBOX"],
            page_size: 25,
            include_spam_trash: false
          },
          "token"
        ) do
      {:ok,
       %{
         threads: [
           Gmail.Thread.new!(%{
             thread_id: "thread123",
             history_id: "456",
             snippet: "Budget update"
           })
         ],
         next_page_token: "next-thread",
         result_size_estimate: 1
       }}
    end

    def get_thread(%{thread_id: "thread123", metadata_headers: ["From", "Subject"]}, "token") do
      {:ok,
       Gmail.Thread.new!(%{
         thread_id: "thread123",
         history_id: "456",
         snippet: "Budget update",
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             snippet: "Budget update"
           })
         ]
       })}
    end

    def list_drafts(
          %{
            query: "to:to@example.com",
            page_size: 25,
            include_spam_trash: false
          },
          "token"
        ) do
      {:ok,
       %{
         drafts: [
           Gmail.Draft.new!(%{
             draft_id: "draft123",
             message:
               Gmail.Message.new!(%{
                 message_id: "draft-message123",
                 thread_id: "thread123"
               })
           })
         ],
         next_page_token: "next-draft",
         result_size_estimate: 1
       }}
    end

    def get_draft(%{draft_id: "draft123", metadata_headers: ["Subject"]}, "token") do
      {:ok,
       Gmail.Draft.new!(%{
         draft_id: "draft123",
         message:
           Gmail.Message.new!(%{
             message_id: "draft-message123",
             thread_id: "thread123",
             headers: [%{name: "Subject", value: "Hello"}]
           })
       })}
    end

    def get_attachment(%{message_id: "msg123", attachment_id: "att123"}, "token") do
      {:ok,
       Gmail.Attachment.new!(%{
         attachment_id: "att123",
         size: 12,
         data: "Ym9keS1ieXRlcw"
       })}
    end

    def list_history(
          %{
            start_history_id: "123",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          } = params,
          "token"
        )
        when not is_map_key(params, :page_token) do
      {:ok,
       %{
         history: [
           %{
             history_id: "124",
             messages_added: [
               Gmail.Message.new!(%{
                 message_id: "msg123",
                 thread_id: "thread123",
                 label_ids: ["INBOX", "UNREAD"],
                 snippet: "Budget update",
                 history_id: "124"
               }),
               Gmail.Message.new!(%{
                 message_id: "msg123",
                 thread_id: "thread123",
                 label_ids: ["INBOX", "UNREAD"],
                 snippet: "Budget update duplicate",
                 history_id: "124"
               })
             ]
           }
         ],
         next_page_token: "page-2",
         history_id: "125"
       }}
    end

    def list_history(
          %{
            start_history_id: "123",
            page_token: "page-2",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          },
          "token"
        ) do
      {:ok,
       %{
         history: [
           %{
             history_id: "125",
             messages_added: [
               Gmail.Message.new!(%{
                 message_id: "msg456",
                 thread_id: "thread456",
                 label_ids: ["INBOX"],
                 snippet: "Next update",
                 history_id: "125"
               })
             ]
           }
         ],
         history_id: "126"
       }}
    end

    def list_history(
          %{
            start_history_id: "126",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          },
          "token"
        ) do
      {:ok, %{history: [], history_id: "126"}}
    end

    def list_history(
          %{
            start_history_id: "expired-history",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          },
          "token"
        ) do
      {:error,
       Connect.Error.provider("Google API request failed",
         provider: :google,
         reason: :http_error,
         status: 404,
         details: %{message: "History ID is too old"}
       )}
    end

    def list_history(
          %{
            start_history_id: "loop-history",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          } = params,
          "token"
        )
        when not is_map_key(params, :page_token) do
      {:ok, %{history: [], next_page_token: "loop-page", history_id: "loop-history"}}
    end

    def list_history(
          %{
            start_history_id: "loop-history",
            page_token: "loop-page",
            history_types: ["messageAdded"],
            label_id: "INBOX",
            page_size: 100
          },
          "token"
        ) do
      {:ok, %{history: [], next_page_token: "loop-page", history_id: "loop-history"}}
    end

    def start_watch(
          %{
            topic_name: "projects/project-1/topics/gmail",
            label_ids: ["INBOX"],
            label_filter_behavior: "include"
          },
          "token"
        ) do
      {:ok, Gmail.Watch.new!(%{history_id: "126", expiration: "1710000000000"})}
    end

    def stop_watch(%{}, "token") do
      {:ok, %{stopped?: true}}
    end

    def send_message(%{raw: raw, to: ["to@example.com"], subject: "Hello"}, "token")
        when is_binary(raw) do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "sent123",
         thread_id: "thread123",
         label_ids: ["SENT"]
       })}
    end

    def create_draft(%{raw: raw, to: ["to@example.com"], subject: "Hello"}, "token")
        when is_binary(raw) do
      {:ok,
       Gmail.Draft.new!(%{
         draft_id: "draft123",
         message:
           Gmail.Message.new!(%{
             message_id: "draft-message123",
             thread_id: "thread123"
           })
       })}
    end

    def update_draft(
          %{draft_id: "draft123", raw: raw, to: ["to@example.com"], subject: "Hello"},
          "token"
        )
        when is_binary(raw) do
      {:ok,
       Gmail.Draft.new!(%{
         draft_id: "draft123",
         message:
           Gmail.Message.new!(%{
             message_id: "draft-message456",
             thread_id: "thread123"
           })
       })}
    end

    def send_draft(%{draft_id: "draft123"}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "sent-draft123",
         thread_id: "thread123",
         label_ids: ["SENT"]
       })}
    end

    def delete_draft(%{draft_id: "draft123"}, "token") do
      {:ok, %{deleted?: true, draft_id: "draft123"}}
    end

    def create_label(%{name: "Customers", message_list_visibility: "show"}, "token") do
      {:ok,
       Gmail.Label.new!(%{
         label_id: "Label_123",
         name: "Customers",
         type: "user",
         message_list_visibility: "show"
       })}
    end

    def update_label(
          %{label_id: "Label_123", name: "Customers VIP", message_list_visibility: "show"},
          "token"
        ) do
      {:ok,
       Gmail.Label.new!(%{
         label_id: "Label_123",
         name: "Customers VIP",
         type: "user",
         message_list_visibility: "show"
       })}
    end

    def delete_label(%{label_id: "Label_123"}, "token") do
      {:ok, %{deleted?: true, label_id: "Label_123"}}
    end

    def apply_message_labels(
          %{message_id: "msg123", add_label_ids: ["Label_123"], remove_label_ids: []},
          "token"
        ) do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "msg123",
         thread_id: "thread123",
         label_ids: ["INBOX", "Label_123"]
       })}
    end

    def batch_modify_messages(
          %{
            message_ids: ["msg123", "msg456"],
            add_label_ids: ["Label_123"],
            remove_label_ids: ["UNREAD"]
          },
          "token"
        ) do
      {:ok,
       %{
         modified?: true,
         message_ids: ["msg123", "msg456"],
         add_label_ids: ["Label_123"],
         remove_label_ids: ["UNREAD"]
       }}
    end

    def trash_message(%{message_id: "msg123"}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "msg123",
         thread_id: "thread123",
         label_ids: ["TRASH"]
       })}
    end

    def untrash_message(%{message_id: "msg123"}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "msg123",
         thread_id: "thread123",
         label_ids: ["INBOX"]
       })}
    end

    def delete_message(%{message_id: "msg123"}, "token") do
      {:ok, %{deleted?: true, message_id: "msg123"}}
    end

    def batch_delete_messages(%{message_ids: ["msg123", "msg456"]}, "token") do
      {:ok, %{deleted?: true, message_ids: ["msg123", "msg456"]}}
    end

    def modify_thread(
          %{
            thread_id: "thread123",
            add_label_ids: ["Label_123"],
            remove_label_ids: ["UNREAD"]
          },
          "token"
        ) do
      {:ok,
       Gmail.Thread.new!(%{
         thread_id: "thread123",
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             label_ids: ["Label_123"]
           })
         ]
       })}
    end

    def trash_thread(%{thread_id: "thread123"}, "token") do
      {:ok,
       Gmail.Thread.new!(%{
         thread_id: "thread123",
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             label_ids: ["TRASH"]
           })
         ]
       })}
    end

    def untrash_thread(%{thread_id: "thread123"}, "token") do
      {:ok,
       Gmail.Thread.new!(%{
         thread_id: "thread123",
         messages: [
           Gmail.Message.new!(%{
             message_id: "msg123",
             thread_id: "thread123",
             label_ids: ["INBOX"]
           })
         ]
       })}
    end

    def delete_thread(%{thread_id: "thread123"}, "token") do
      {:ok, %{deleted?: true, thread_id: "thread123"}}
    end
  end

  defmodule ListSpyGmailClient do
    def list_messages(params, "token") do
      send(self(), {:gmail_client_called, :list_messages, params})
      {:ok, %{messages: []}}
    end

    def list_threads(params, "token") do
      send(self(), {:gmail_client_called, :list_threads, params})
      {:ok, %{threads: []}}
    end
  end

  defmodule LabelSpyGmailClient do
    def apply_message_labels(params, "token") do
      send(self(), {:gmail_client_called, :apply_message_labels, params})
      {:error, Connect.Error.provider("not served", provider: :google)}
    end
  end

  defmodule ComposeSpyGmailClient do
    def send_message(params, "token") do
      send(self(), {:gmail_client_called, :send_message, params})
      {:error, Connect.Error.provider("not served", provider: :google)}
    end

    def create_draft(params, "token") do
      send(self(), {:gmail_client_called, :create_draft, params})
      {:error, Connect.Error.provider("not served", provider: :google)}
    end

    def update_draft(params, "token") do
      send(self(), {:gmail_client_called, :update_draft, params})
      {:error, Connect.Error.provider("not served", provider: :google)}
    end
  end

  defmodule RecordedContentGmailClient do
    # Serves format=full responses recorded from the live test account and
    # reports each call to the test process.

    def get_message_content(params, "token") do
      send(self(), {:gmail_client_called, :get_message_content, params})
      {:ok, LiveSmoke.fixture!(:gmail, "message_full_forward_attached")}
    end

    def get_thread_content(params, "token") do
      send(self(), {:gmail_client_called, :get_thread_content, params})
      {:ok, LiveSmoke.fixture!(:gmail, "thread_full_conversation")}
    end

    def get_attachment(params, "token") do
      send(self(), {:gmail_client_called, :get_attachment, params})
      {:error, Connect.Error.provider("not served", provider: :google)}
    end
  end

  defmodule RecordedHistoryGmailClient do
    # Serves profile and history.list responses recorded from the live test
    # account through the client's response handlers, so a poll sees what
    # Client.get_profile/2 and Client.list_history/2 return for them. Each
    # history request reports its query, encoded as the client sends it, to
    # the test process.
    #
    # message_changed_history holds the live run of google.gmail.message.changed
    # in history_live_smoke_test.exs: the disposable message archived, trashed,
    # restored and permanently deleted, two history records per page, and an
    # empty last page. Any checkpoint gets these pages in nextPageToken order;
    # the start history IDs below select the other responses.

    alias Jido.Connect.Gmail.Client.{Params, Response}
    alias Jido.Connect.TestSupport.LiveSmoke

    @pages ~w(message_changed_history message_changed_history.2 message_changed_history.3
              message_changed_history.4)

    def recorded_pages, do: Enum.map(@pages, &LiveSmoke.fixture!(:gmail, &1))

    def get_profile(%{}, "token") do
      send(self(), {:gmail_client_called, :get_profile})

      Response.handle_profile_response(
        {:ok, %{status: 200, body: LiveSmoke.fixture!(:gmail, "profile")}}
      )
    end

    def list_history(params, "token") do
      send(self(), {:gmail_history_request, Params.history_list_params(params)})
      history_response(params.start_history_id, Map.get(params, :page_token))
    end

    # Recorded with status 404 for startHistoryId=1.
    defp history_response("1", nil) do
      Response.handle_history_list_response(
        {:ok, %{status: 404, body: LiveSmoke.fixture!(:gmail, "message_changed_expired")}}
      )
    end

    # Derived: Gmail never repeated a nextPageToken. This checkpoint gets the
    # first recorded page for every request, so its token comes back.
    defp history_response("repeated-page-token", _page_token), do: ok(hd(recorded_pages()))

    defp history_response("derived-records", nil), do: ok(derived_page())
    defp history_response("derived-two-changes", nil), do: ok(two_changes_page())

    defp history_response(_checkpoint, page_token) do
      pages = recorded_pages()

      page =
        case page_token do
          nil -> hd(pages)
          token -> pages |> Enum.drop_while(&(&1["nextPageToken"] != token)) |> Enum.at(1)
        end

      ok(page)
    end

    # Derived from the recorded run. Gmail returned one message per record,
    # and it leaves messagesAdded records out of a list filtered to the three
    # change types. The archive, Trash and delete records here each also
    # carry the same change of a second message, the first message of the
    # recorded query search, and the second recorded record with `messages`
    # only gets a messagesAdded entry for its message. The first such record
    # stays as recorded.
    defp derived_page do
      [first, second, third, last] = recorded_pages()
      %{"history" => [messages_only, %{"labelsRemoved" => [archived]} = archive]} = first
      %{"history" => [%{"labelsAdded" => [trashed]} = trash, added_only]} = second
      %{"history" => [_restore, %{"messagesDeleted" => [deleted]} = delete]} = third

      %{"messages" => [%{"id" => other_id, "threadId" => other_thread_id} | _rest]} =
        LiveSmoke.fixture!(:gmail, "messages_list_query")

      other = fn entry ->
        put_in(entry, ["message"], %{
          entry["message"]
          | "id" => other_id,
            "threadId" => other_thread_id
        })
      end

      %{
        "history" => [
          messages_only,
          %{archive | "labelsRemoved" => [archived, other.(archived)]},
          %{trash | "labelsAdded" => [trashed, other.(trashed)]},
          Map.put(added_only, "messagesAdded", [%{"message" => hd(added_only["messages"])}]),
          %{delete | "messagesDeleted" => [deleted, other.(deleted)]}
        ],
        "historyId" => last["historyId"]
      }
    end

    # Derived from the recorded run, where each record held one change. The
    # archive record here also carries the recorded TRASH addition of the same
    # message, so one record both adds and removes a label of one message.
    defp two_changes_page do
      [first, second | _rest] = recorded_pages()
      %{"history" => [_messages_only, archive]} = first
      %{"history" => [%{"labelsAdded" => trashed}, _added_only]} = second

      %{
        "history" => [Map.put(archive, "labelsAdded", trashed)],
        "historyId" => first["historyId"]
      }
    end

    defp ok(body), do: Response.handle_history_list_response({:ok, %{status: 200, body: body}})
  end

  test "declares Gmail provider metadata" do
    spec = Gmail.integration()

    assert spec.id == :gmail
    assert spec.package == :jido_connect_gmail
    assert spec.name == "Gmail"
    assert spec.category == :email
    assert spec.tags == [:google, :workspace, :email, :productivity]

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Gmail,
      id_prefix: "google.gmail.",
      pack_id_prefix: "google_gmail_",
      module_namespace: Jido.Connect.Gmail
    )

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/gmail.metadata" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.labels" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.send" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.compose" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.modify" in profile.optional_scopes
    assert "https://mail.google.com/" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "google.gmail.profile.get",
             "google.gmail.labels.list",
             "google.gmail.label.get",
             "google.gmail.messages.list",
             "google.gmail.message.get",
             "google.gmail.threads.list",
             "google.gmail.thread.get",
             "google.gmail.drafts.list",
             "google.gmail.draft.get",
             "google.gmail.history.list",
             "google.gmail.message.attachment.get",
             "google.gmail.message.content.get",
             "google.gmail.thread.content.get",
             "google.gmail.message.attachment.content.get",
             "google.gmail.message.send",
             "google.gmail.draft.create",
             "google.gmail.draft.update",
             "google.gmail.draft.send",
             "google.gmail.draft.delete",
             "google.gmail.label.create",
             "google.gmail.label.update",
             "google.gmail.label.delete",
             "google.gmail.message.labels.apply",
             "google.gmail.messages.batch_modify",
             "google.gmail.message.trash",
             "google.gmail.message.untrash",
             "google.gmail.message.delete",
             "google.gmail.messages.batch_delete",
             "google.gmail.thread.modify",
             "google.gmail.thread.trash",
             "google.gmail.thread.untrash",
             "google.gmail.thread.delete",
             "google.gmail.watch.start",
             "google.gmail.watch.stop"
           ]

    send_action = Enum.find(spec.actions, &(&1.id == "google.gmail.message.send"))
    assert send_action.risk == :external_write
    assert send_action.confirmation == :required_for_ai

    for id <- ["google.gmail.draft.create", "google.gmail.draft.update"] do
      assert %{risk: :write, confirmation: :required_for_ai} =
               Enum.find(spec.actions, &(&1.id == id))
    end

    assert {:ok,
            %{
              id: "google.gmail.message.received",
              kind: :poll,
              checkpoint: :history_id,
              dedupe: %{key: [:message_id]},
              scope_resolver: Jido.Connect.Gmail.ScopeResolver
            }} =
             Connect.trigger(spec, "google.gmail.message.received")

    assert {:ok,
            %{
              id: "google.gmail.message.changed",
              kind: :poll,
              interval_ms: 300_000,
              checkpoint: :history_id,
              dedupe: %{key: [:history_id, :message_id, :change_type]},
              scopes: ["https://www.googleapis.com/auth/gmail.metadata"],
              scope_resolver: Jido.Connect.Gmail.ScopeResolver
            } = changed} =
             Connect.trigger(spec, "google.gmail.message.changed")

    assert Enum.map(changed.config, &{&1.name, &1.default}) == [page_size: 100, label_id: nil]

    assert Enum.map(changed.signal, & &1.name) == [
             :change_type,
             :message_id,
             :thread_id,
             :history_id,
             :changed_label_ids,
             :label_ids
           ]

    assert {:ok,
            %{
              id: "google.gmail.mailbox.changed",
              kind: :webhook,
              verification: %{kind: :google_pubsub_push, oidc: :host_verified},
              dedupe: %{key: [:history_id]},
              scope_resolver: Jido.Connect.Gmail.ScopeResolver
            }} =
             Connect.trigger(spec, "google.gmail.mailbox.changed")
  end

  test "compiles generated Jido modules for actions, sensors, and plugin" do
    ConnectorContracts.assert_generated_surface(Gmail,
      otp_app: :jido_connect_gmail,
      action_modules: @gmail_action_modules,
      sensor_specs: [
        %{
          module: Jido.Connect.Gmail.Sensors.MessageReceived,
          name: "google_gmail_message_received",
          trigger_id: "google.gmail.message.received",
          signal_type: "google.gmail.message.received"
        },
        %{
          module: Jido.Connect.Gmail.Sensors.MessageChanged,
          name: "google_gmail_message_changed",
          trigger_id: "google.gmail.message.changed",
          signal_type: "google.gmail.message.changed"
        },
        %{
          module: Jido.Connect.Gmail.Sensors.MailboxChanged,
          name: "google_gmail_mailbox_changed",
          trigger_id: "google.gmail.mailbox.changed",
          signal_type: "google.gmail.mailbox.changed"
        }
      ],
      plugin_module: Jido.Connect.Gmail.Plugin,
      plugin_name: "gmail"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Gmail,
      metadata_pack: :google_gmail_metadata,
      triage_pack: :google_gmail_triage,
      send_pack: :google_gmail_send,
      destructive_pack: :google_gmail_destructive,
      content_pack: :google_gmail_content
    )

    ConnectorContracts.assert_plugin_tool_availability(Gmail)
  end

  test "loads Gmail Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@gmail_dsl_fragments)
  end

  test "resolves Gmail scopes for broad grants and operation shapes" do
    resolver = Jido.Connect.Gmail.ScopeResolver

    ConnectorContracts.assert_scope_resolver_shape(resolver, [
      "https://www.googleapis.com/auth/gmail.metadata"
    ])

    assert resolver.required_scopes(
             %{id: "google.gmail.message.send"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.compose"]}
           ) == ["https://www.googleapis.com/auth/gmail.compose"]

    assert resolver.required_scopes(
             %{action_id: "google.gmail.draft.create"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.modify"]}
           ) == ["https://www.googleapis.com/auth/gmail.modify"]

    assert resolver.required_scopes(
             %{id: "google.gmail.label.update"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.labels"]}
           ) == ["https://www.googleapis.com/auth/gmail.labels"]

    assert resolver.required_scopes(
             %{id: "google.gmail.messages.batch_modify"},
             %{},
             %{scopes: ["https://mail.google.com/"]}
           ) == ["https://mail.google.com/"]

    assert resolver.required_scopes(
             %{id: "google.gmail.message.delete"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.modify"]}
           ) == ["https://mail.google.com/"]

    assert resolver.required_scopes(
             %{id: "google.gmail.message.get"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.readonly"]}
           ) == ["https://www.googleapis.com/auth/gmail.readonly"]

    assert resolver.required_scopes(
             %{id: "google.gmail.message.attachment.get"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.metadata"]}
           ) == ["https://www.googleapis.com/auth/gmail.readonly"]

    assert resolver.required_scopes(
             %{id: "google.gmail.watch.start"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/gmail.metadata"]}
           ) == ["https://www.googleapis.com/auth/gmail.metadata"]

    assert resolver.required_scopes(%{}, %{}, %{}) == [
             "https://www.googleapis.com/auth/gmail.metadata"
           ]
  end

  test "invokes get profile through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              profile: %{
                email_address: "user@example.com",
                messages_total: 10,
                threads_total: 5,
                history_id: "123"
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.profile.get",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list labels through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              labels: [
                %{
                  label_id: "INBOX",
                  name: "INBOX",
                  type: "system"
                }
              ]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.labels.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get label through injected client and lease" do
    {context, lease} = context_and_lease(scopes: readonly_scopes())

    assert {:ok, %{label: %{label_id: "Label_123", name: "Customers"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.get",
               %{label_id: "Label_123"},
               context: context,
               credential_lease: lease
             )
  end

  test "metadata actions accept broader Gmail readonly scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/gmail.readonly"
        ]
      )

    assert {:ok, %{profile: %{email_address: "user@example.com"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.profile.get",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "fails before handler execution when required Gmail scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.metadata"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.profile.get",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list messages through injected client and lease" do
    {context, lease} = context_and_lease(scopes: readonly_scopes())

    assert {:ok,
            %{
              messages: [
                %{
                  message_id: "msg123",
                  thread_id: "thread123",
                  snippet: "Budget update"
                }
              ],
              next_page_token: "next",
              result_size_estimate: 1
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.messages.list",
               %{query: "from:sender@example.com", label_ids: ["INBOX"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get message metadata through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              message: %{
                message_id: "msg123",
                thread_id: "thread123",
                snippet: "Budget update",
                headers: [
                  %{name: "From", value: "sender@example.com"},
                  %{name: "Subject", value: "Budget"}
                ]
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.get",
               %{message_id: "msg123", metadata_headers: ["From", "Subject"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list threads through injected client and lease" do
    {context, lease} = context_and_lease(scopes: readonly_scopes())

    assert {:ok,
            %{
              threads: [
                %{
                  thread_id: "thread123",
                  history_id: "456",
                  snippet: "Budget update"
                }
              ],
              next_page_token: "next-thread",
              result_size_estimate: 1
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.threads.list",
               %{query: "label:inbox", label_ids: ["INBOX"]},
               context: context,
               credential_lease: lease
             )
  end

  test "list searches with a query need a read grant before the client is called" do
    {context, lease} = context_and_lease(gmail_client: ListSpyGmailClient)

    for action_id <- ["google.gmail.messages.list", "google.gmail.threads.list"],
        query <- ["subject:report", "  "] do
      assert {:error,
              %Connect.Error.AuthError{
                reason: :missing_scopes,
                missing_scopes: ["https://www.googleapis.com/auth/gmail.readonly"]
              }} =
               Connect.invoke(
                 Gmail.integration(),
                 action_id,
                 %{query: query},
                 context: context,
                 credential_lease: lease
               )
    end

    refute_received {:gmail_client_called, _function, _params}
  end

  test "list requests without a query run on a metadata-only grant" do
    {context, lease} = context_and_lease(gmail_client: ListSpyGmailClient)

    assert {:ok, %{messages: []}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.messages.list",
               %{label_ids: ["INBOX"]},
               context: context,
               credential_lease: lease
             )

    assert_received {:gmail_client_called, :list_messages, %{label_ids: ["INBOX"]}}

    assert {:ok, %{threads: []}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.threads.list",
               %{},
               context: context,
               credential_lease: lease
             )

    assert_received {:gmail_client_called, :list_threads, %{page_size: 25}}
  end

  test "invokes get thread metadata through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              thread: %{
                thread_id: "thread123",
                history_id: "456",
                messages: [%{message_id: "msg123"}]
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.get",
               %{thread_id: "thread123", metadata_headers: ["From", "Subject"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes draft read actions through injected client and lease" do
    {context, lease} = context_and_lease(scopes: compose_scopes())

    assert {:ok,
            %{
              drafts: [
                %{
                  draft_id: "draft123",
                  message: %{message_id: "draft-message123"}
                }
              ],
              next_page_token: "next-draft",
              result_size_estimate: 1
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.drafts.list",
               %{query: "to:to@example.com"},
               context: context,
               credential_lease: lease
             )

    assert {:ok,
            %{
              draft: %{
                draft_id: "draft123",
                message: %{message_id: "draft-message123", headers: [%{name: "Subject"}]}
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.get",
               %{draft_id: "draft123", metadata_headers: ["Subject"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list history through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              history: [
                %{
                  history_id: "124",
                  messages_added: [%{message_id: "msg123"}, %{message_id: "msg123"}]
                }
              ],
              next_page_token: "page-2",
              history_id: "125"
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.history.list",
               %{
                 start_history_id: "123",
                 history_types: ["messageAdded"],
                 label_id: "INBOX"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "history list validates checkpoint inputs before client calls" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_start_history_id,
              details: %{expected: "non-empty string"}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.history.list",
               %{start_history_id: "  "},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_history_page_size,
              details: %{max_page_size: 500}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.history.list",
               %{start_history_id: "123", page_size: 501},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get attachment through injected client and lease" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/gmail.readonly"
        ]
      )

    assert {:ok,
            %{
              attachment: %{
                message_id: "msg123",
                attachment_id: "att123",
                size: 12,
                data: "Ym9keS1ieXRlcw"
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.attachment.get",
               %{message_id: "msg123", attachment_id: "att123"},
               context: context,
               credential_lease: lease
             )
  end

  test "content reads run on a gmail.readonly lease" do
    {context, lease} =
      context_and_lease(scopes: readonly_scopes(), gmail_client: RecordedContentGmailClient)

    %{"id" => message_id} = LiveSmoke.fixture!(:gmail, "message_full_forward_attached")
    %{"id" => thread_id} = LiveSmoke.fixture!(:gmail, "thread_full_conversation")

    assert {:ok, %{message: message}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.content.get",
               %{message_id: message_id},
               context: context,
               credential_lease: lease
             )

    assert_received {:gmail_client_called, :get_message_content, %{message_id: ^message_id}}
    assert %{message_id: ^message_id, subject: "Fwd: jcl-live attached originals"} = message

    assert [%{part_id: "0", content: "Two originals attached as messages.\r\n"}] =
             message.text_parts

    assert {:ok, %{thread: thread}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.content.get",
               %{thread_id: thread_id},
               context: context,
               credential_lease: lease
             )

    assert_received {:gmail_client_called, :get_thread_content, %{thread_id: ^thread_id}}
    assert %{thread_id: ^thread_id, messages: [_received, _sent, _later]} = thread
    refute_received {:gmail_client_called, :get_attachment, _params}
  end

  test "content reads stop metadata-only, compose-only and send-only leases before the client call" do
    for scopes <- [metadata_scopes(), compose_scopes(), send_scopes()],
        {action_id, input} <- [
          {"google.gmail.message.content.get", %{message_id: "msg123"}},
          {"google.gmail.thread.content.get", %{thread_id: "thread123"}}
        ] do
      {context, lease} =
        context_and_lease(scopes: scopes, gmail_client: RecordedContentGmailClient)

      assert {:error,
              %Connect.Error.AuthError{
                reason: :missing_scopes,
                missing_scopes: ["https://www.googleapis.com/auth/gmail.readonly"]
              }} =
               Connect.invoke(Gmail.integration(), action_id, input,
                 context: context,
                 credential_lease: lease
               ),
             "#{action_id} with #{inspect(scopes)}"
    end

    refute_received {:gmail_client_called, _function, _params}
  end

  test "content reads reject blank IDs and a max_messages below one before the client call" do
    {context, lease} =
      context_and_lease(scopes: readonly_scopes(), gmail_client: RecordedContentGmailClient)

    for {action_id, input, reason} <- [
          {"google.gmail.message.content.get", %{message_id: "  "}, :invalid_gmail_id},
          {"google.gmail.thread.content.get", %{thread_id: ""}, :invalid_gmail_id},
          {"google.gmail.thread.content.get", %{thread_id: "thread123", max_messages: 0},
           :invalid_max_messages}
        ] do
      assert {:error, %Connect.Error.ValidationError{reason: ^reason}} =
               Connect.invoke(Gmail.integration(), action_id, input,
                 context: context,
                 credential_lease: lease
               )
    end

    refute_received {:gmail_client_called, _function, _params}
  end

  test "invokes watch lifecycle through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{watch: %{history_id: "126", expiration: "1710000000000"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.watch.start",
               %{
                 topic_name: "projects/project-1/topics/gmail",
                 label_ids: ["INBOX"],
                 label_filter_behavior: "include"
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{stopped?: true}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.watch.stop",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "watch start validates topic names before client calls" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_watch_topic_name,
              details: %{expected: "projects/{project}/topics/{topic}"}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.watch.start",
               %{topic_name: ""},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes send message through injected client and lease" do
    {context, lease} = context_and_lease(scopes: send_scopes())

    assert {:ok, %{message: %{message_id: "sent123", label_ids: ["SENT"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.send",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create draft through injected client and lease" do
    {context, lease} = context_and_lease(scopes: compose_scopes())

    assert {:ok, %{draft: %{draft_id: "draft123", message: %{message_id: "draft-message123"}}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.create",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update and delete draft through injected client and lease" do
    {context, lease} = context_and_lease(scopes: compose_scopes())

    assert {:ok, %{draft: %{draft_id: "draft123", message: %{message_id: "draft-message456"}}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.update",
               %{
                 draft_id: "draft123",
                 to: ["to@example.com"],
                 subject: "Hello",
                 body_text: "Body"
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{deleted?: true, draft_id: "draft123"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.delete",
               %{draft_id: "draft123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes send draft through injected client and lease" do
    {context, lease} = context_and_lease(scopes: compose_scopes())

    assert {:ok, %{message: %{message_id: "sent-draft123", label_ids: ["SENT"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.draft.send",
               %{draft_id: "draft123"},
               context: context,
               credential_lease: lease
             )
  end

  test "send and draft actions validate recipients and body inputs" do
    {context, lease} = context_and_lease(scopes: send_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_recipient,
              details: %{field: :to}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.send",
               %{to: ["not-an-email"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "send and draft actions reject a line break in a header value before the client call" do
    # gmail.compose satisfies send as well as the draft writes.
    {context, lease} =
      context_and_lease(scopes: compose_scopes(), gmail_client: ComposeSpyGmailClient)

    message = %{to: ["to@example.com"], subject: "Hello", body_text: "Body"}

    actions = [
      {"google.gmail.message.send", :send_message, message},
      {"google.gmail.draft.create", :create_draft, message},
      {"google.gmail.draft.update", :update_draft, Map.put(message, :draft_id, "draft123")}
    ]

    for {action_id, _function, input} <- actions,
        {field, value} <- [
          subject: "Hi\r\nBcc: x@example.com",
          in_reply_to: "<a@example.com>\n",
          references: "<a@example.com>\r<b@example.com>"
        ] do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :invalid_header_value,
                details: %{field: ^field}
              }} =
               Connect.invoke(Gmail.integration(), action_id, Map.put(input, field, value),
                 context: context,
                 credential_lease: lease
               )
    end

    refute_received {:gmail_client_called, _function, _params}

    # The same inputs without the break reach the client.
    for {action_id, function, input} <- actions do
      assert {:error, %Connect.Error.ProviderError{}} =
               Connect.invoke(Gmail.integration(), action_id, input,
                 context: context,
                 credential_lease: lease
               )

      assert_received {:gmail_client_called, ^function, _params}
    end
  end

  test "send action requires dynamic send-capable scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.send"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.send",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create label through injected client and lease" do
    {context, lease} = context_and_lease(scopes: labels_scopes())

    assert {:ok,
            %{
              label: %{
                label_id: "Label_123",
                name: "Customers",
                type: "user",
                message_list_visibility: "show"
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.create",
               %{name: " Customers ", message_list_visibility: "show"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update and delete label through injected client and lease" do
    {context, lease} = context_and_lease(scopes: labels_scopes())

    assert {:ok,
            %{
              label: %{
                label_id: "Label_123",
                name: "Customers VIP",
                message_list_visibility: "show"
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.update",
               %{label_id: "Label_123", name: "Customers VIP", message_list_visibility: "show"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{deleted?: true, label_id: "Label_123"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.delete",
               %{label_id: "Label_123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes apply message labels through injected client and lease" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:ok, %{message: %{message_id: "msg123", label_ids: ["INBOX", "Label_123"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.labels.apply",
               %{message_id: "msg123", add_label_ids: [" Label_123 "]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch message and thread lifecycle actions through injected client and lease" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:ok,
            %{
              result: %{
                modified?: true,
                message_ids: ["msg123", "msg456"],
                add_label_ids: ["Label_123"],
                remove_label_ids: ["UNREAD"]
              }
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.messages.batch_modify",
               %{
                 message_ids: ["msg123", "msg456"],
                 add_label_ids: ["Label_123"],
                 remove_label_ids: ["UNREAD"]
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{message: %{message_id: "msg123", label_ids: ["TRASH"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.trash",
               %{message_id: "msg123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{message: %{message_id: "msg123", label_ids: ["INBOX"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.untrash",
               %{message_id: "msg123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{thread: %{thread_id: "thread123", messages: [%{label_ids: ["Label_123"]}]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.modify",
               %{
                 thread_id: "thread123",
                 add_label_ids: ["Label_123"],
                 remove_label_ids: ["UNREAD"]
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{thread: %{thread_id: "thread123", messages: [%{label_ids: ["TRASH"]}]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.trash",
               %{thread_id: "thread123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{thread: %{thread_id: "thread123", messages: [%{label_ids: ["INBOX"]}]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.untrash",
               %{thread_id: "thread123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes permanent message and thread deletes through injected client and lease" do
    {context, lease} = context_and_lease(scopes: mail_scopes())

    assert {:ok, %{result: %{deleted?: true, message_id: "msg123"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.delete",
               %{message_id: "msg123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{deleted?: true, message_ids: ["msg123", "msg456"]}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.messages.batch_delete",
               %{message_ids: ["msg123", "msg456"]},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{deleted?: true, thread_id: "thread123"}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.delete",
               %{thread_id: "thread123"},
               context: context,
               credential_lease: lease
             )
  end

  test "label apply validates non-empty label changes" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_label_mutation,
              details: %{field: :labels}
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.labels.apply",
               %{message_id: "msg123"},
               context: context,
               credential_lease: lease
             )
  end

  test "label apply rejects a blank added or removed label ID before the client call" do
    {context, lease} =
      context_and_lease(scopes: modify_scopes(), gmail_client: LabelSpyGmailClient)

    for {input, field} <- [
          {%{add_label_ids: [""]}, :add_label_ids},
          {%{remove_label_ids: ["  "]}, :remove_label_ids}
        ] do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :invalid_label_mutation,
                details: %{field: ^field}
              }} =
               Connect.invoke(
                 Gmail.integration(),
                 "google.gmail.message.labels.apply",
                 Map.put(input, :message_id, "msg123"),
                 context: context,
                 credential_lease: lease
               )
    end

    refute_received {:gmail_client_called, :apply_message_labels, _params}
  end

  test "label lifecycle actions require label scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.labels"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.create",
               %{name: "Customers"},
               context: context,
               credential_lease: lease
             )
  end

  test "message label mutations require modify scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.modify"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.labels.apply",
               %{message_id: "msg123", add_label_ids: ["Label_123"]},
               context: context,
               credential_lease: lease
             )
  end

  test "message label mutations refuse a gmail.labels-only lease before the client call" do
    {context, lease} =
      context_and_lease(scopes: labels_scopes(), gmail_client: LabelSpyGmailClient)

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.modify"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.labels.apply",
               %{message_id: "msg123", add_label_ids: ["Label_123"]},
               context: context,
               credential_lease: lease
             )

    refute_received {:gmail_client_called, :apply_message_labels, _params}
  end

  test "permanent deletes require full Gmail mailbox scope" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://mail.google.com/"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.delete",
               %{message_id: "msg123"},
               context: context,
               credential_lease: lease
             )
  end

  test "message received poll initializes checkpoint without replaying history" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "123"}} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "message received poll drains history pages, dedupes messages, and advances checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  message_id: "msg123",
                  thread_id: "thread123",
                  history_id: "124",
                  label_ids: ["INBOX", "UNREAD"],
                  snippet: "Budget update",
                  message: %{message_id: "msg123", snippet: "Budget update"}
                },
                %{
                  message_id: "msg456",
                  thread_id: "thread456",
                  history_id: "125",
                  label_ids: ["INBOX"],
                  snippet: "Next update"
                }
              ],
              checkpoint: "126"
            }} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "123"
             )
  end

  test "message received poll emits no duplicates after checkpoint advances" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "126"}} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "126"
             )
  end

  test "message received poll surfaces expired history ids as checkpoint errors" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :checkpoint_expired,
              status: 404,
              details: %{
                checkpoint: "expired-history",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "expired-history"
             )
  end

  test "message received poll surfaces repeated page tokens with reset guidance" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{
                next_page_token: "loop-page",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.received",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "loop-history"
             )
  end

  test "message changed poll initializes the checkpoint from the profile without signals" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)
    %{"historyId" => history_id} = LiveSmoke.fixture!(:gmail, "profile")

    assert {:ok, %{signals: [], checkpoint: ^history_id}} =
             Connect.poll(
               Gmail.integration(),
               "google.gmail.message.changed",
               %{},
               context: context,
               credential_lease: lease
             )

    assert_received {:gmail_client_called, :get_profile}
    refute_received {:gmail_history_request, _query}
  end

  test "message changed poll sends the checkpoint with the three change types, drains every page and returns the newest historyId" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)

    [
      %{
        "history" => [
          %{"messages" => [_only]},
          %{
            "id" => archived,
            "labelsRemoved" => [%{"message" => %{"id" => message_id, "threadId" => thread_id}}]
          }
        ],
        "nextPageToken" => second_page
      },
      %{
        "history" => [%{"id" => trashed, "labelsAdded" => [_trash]}, %{"messages" => [_]}],
        "nextPageToken" => third_page
      },
      %{
        "history" => [
          %{"id" => restored, "labelsRemoved" => [_restore]},
          %{"id" => deleted, "messagesDeleted" => [_delete]}
        ],
        "nextPageToken" => last_page
      },
      %{"historyId" => newest} = empty
    ] = RecordedHistoryGmailClient.recorded_pages()

    refute Map.has_key?(empty, "history")

    assert {:ok, %{signals: [], checkpoint: checkpoint}} =
             poll_changes(%{page_size: 2}, nil, context, lease)

    assert {:ok, %{signals: signals, checkpoint: ^newest}} =
             poll_changes(%{page_size: 2}, checkpoint, context, lease)

    assert signals == [
             %{
               change_type: "label_removed",
               message_id: message_id,
               thread_id: thread_id,
               history_id: archived,
               changed_label_ids: ["INBOX"],
               label_ids: []
             },
             %{
               change_type: "label_added",
               message_id: message_id,
               thread_id: thread_id,
               history_id: trashed,
               changed_label_ids: ["TRASH"],
               label_ids: ["TRASH"]
             },
             %{
               change_type: "label_removed",
               message_id: message_id,
               thread_id: thread_id,
               history_id: restored,
               changed_label_ids: ["TRASH"],
               label_ids: []
             },
             %{
               change_type: "message_deleted",
               message_id: message_id,
               thread_id: thread_id,
               history_id: deleted,
               changed_label_ids: [],
               label_ids: []
             }
           ]

    for page_token <- [nil, second_page, third_page, last_page] do
      assert_received {:gmail_history_request, query}

      assert Enum.sort(query) ==
               Enum.sort(
                 [
                   startHistoryId: checkpoint,
                   maxResults: 2,
                   historyTypes: "messageDeleted",
                   historyTypes: "labelAdded",
                   historyTypes: "labelRemoved"
                 ] ++ if(page_token, do: [pageToken: page_token], else: [])
               )
    end

    refute_received {:gmail_history_request, _query}
  end

  test "message changed poll sends a configured label_id and the default page size" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)

    assert {:ok, %{signals: [_archive, _trash, _restore, _delete]}} =
             poll_changes(%{label_id: "Label_1"}, "1000", context, lease)

    assert_received {:gmail_history_request, query}

    assert Enum.sort(query) ==
             Enum.sort(
               startHistoryId: "1000",
               labelId: "Label_1",
               maxResults: 100,
               historyTypes: "messageDeleted",
               historyTypes: "labelAdded",
               historyTypes: "labelRemoved"
             )
  end

  test "message changed poll emits one signal per message of a record and none for records without changes" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)

    [
      %{
        "history" => [
          _only,
          %{
            "id" => archived,
            "labelsRemoved" => [%{"message" => %{"id" => message_id, "threadId" => thread_id}}]
          }
        ]
      },
      %{"history" => [%{"id" => trashed}, _]},
      %{"history" => [_restore, %{"id" => deleted}]},
      _empty
    ] = RecordedHistoryGmailClient.recorded_pages()

    %{"messages" => [%{"id" => other_id, "threadId" => other_thread_id} | _rest]} =
      LiveSmoke.fixture!(:gmail, "messages_list_query")

    assert other_id != message_id

    assert {:ok, %{signals: signals}} = poll_changes(%{}, "derived-records", context, lease)

    assert Enum.map(
             signals,
             &{&1.change_type, &1.history_id, &1.message_id, &1.thread_id, &1.changed_label_ids}
           ) == [
             {"label_removed", archived, message_id, thread_id, ["INBOX"]},
             {"label_removed", archived, other_id, other_thread_id, ["INBOX"]},
             {"label_added", trashed, message_id, thread_id, ["TRASH"]},
             {"label_added", trashed, other_id, other_thread_id, ["TRASH"]},
             {"message_deleted", deleted, message_id, thread_id, []},
             {"message_deleted", deleted, other_id, other_thread_id, []}
           ]
  end

  test "message changed poll emits both label changes of one message in a derived record, the addition first" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)

    [
      %{
        "history" => [
          _only,
          %{
            "id" => archived,
            "labelsRemoved" => [%{"message" => %{"id" => message_id, "threadId" => thread_id}}]
          }
        ]
      }
      | _rest
    ] = RecordedHistoryGmailClient.recorded_pages()

    assert {:ok, %{signals: signals}} = poll_changes(%{}, "derived-two-changes", context, lease)

    assert Enum.map(
             signals,
             &{&1.change_type, &1.history_id, &1.message_id, &1.thread_id, &1.changed_label_ids}
           ) == [
             {"label_added", archived, message_id, thread_id, ["TRASH"]},
             {"label_removed", archived, message_id, thread_id, ["INBOX"]}
           ]
  end

  test "message changed poll surfaces an expired history ID as a checkpoint error" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)

    %{"error" => %{"message" => provider_message}} =
      LiveSmoke.fixture!(:gmail, "message_changed_expired")

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :checkpoint_expired,
              status: 404,
              details: %{
                checkpoint: "1",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                },
                provider_details: %{message: ^provider_message}
              }
            }} = poll_changes(%{}, "1", context, lease)
  end

  test "message changed poll surfaces a repeated page token with reset guidance" do
    {context, lease} = context_and_lease(gmail_client: RecordedHistoryGmailClient)
    %{"nextPageToken" => page_token} = hd(RecordedHistoryGmailClient.recorded_pages())

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{
                next_page_token: ^page_token,
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} = poll_changes(%{}, "repeated-page-token", context, lease)

    assert_received {:gmail_history_request, first}
    refute Keyword.has_key?(first, :pageToken)
    assert_received {:gmail_history_request, second}
    assert Keyword.get(second, :pageToken) == page_token
    refute_received {:gmail_history_request, _query}
  end

  test "message changed poll runs on a metadata-only lease and stops a send-only lease before the client call" do
    {context, lease} =
      context_and_lease(scopes: send_scopes(), gmail_client: RecordedHistoryGmailClient)

    for checkpoint <- [nil, "1000"] do
      assert {:error,
              %Connect.Error.AuthError{
                reason: :missing_scopes,
                missing_scopes: ["https://www.googleapis.com/auth/gmail.metadata"]
              }} = poll_changes(%{}, checkpoint, context, lease)
    end

    refute_received {:gmail_client_called, :get_profile}
    refute_received {:gmail_history_request, _query}

    {context, lease} =
      context_and_lease(scopes: metadata_scopes(), gmail_client: RecordedHistoryGmailClient)

    assert {:ok, %{signals: [], checkpoint: checkpoint}} =
             poll_changes(%{}, nil, context, lease)

    assert {:ok, %{signals: [_archive, _trash, _restore, _delete]}} =
             poll_changes(%{}, checkpoint, context, lease)

    assert_received {:gmail_client_called, :get_profile}
    assert_received {:gmail_history_request, _query}
  end

  defp poll_changes(config, checkpoint, context, lease) do
    Connect.poll(Gmail.integration(), "google.gmail.message.changed", config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/gmail.metadata"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{
          access_token: "token",
          gmail_client: Keyword.get(opts, :gmail_client, FakeGmailClient)
        },
        scopes: scopes
      })

    {context, lease}
  end

  defp metadata_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.metadata"
    ]
  end

  defp send_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.send"
    ]
  end

  defp compose_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.compose"
    ]
  end

  defp labels_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.labels"
    ]
  end

  defp readonly_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.readonly"
    ]
  end

  defp modify_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.modify"
    ]
  end

  defp mail_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://mail.google.com/"
    ]
  end
end
