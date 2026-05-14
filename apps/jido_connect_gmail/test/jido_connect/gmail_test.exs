defmodule Jido.Connect.GmailTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @gmail_action_modules [
    Jido.Connect.Gmail.Actions.GetProfile,
    Jido.Connect.Gmail.Actions.ListLabels,
    Jido.Connect.Gmail.Actions.ListMessages,
    Jido.Connect.Gmail.Actions.GetMessage,
    Jido.Connect.Gmail.Actions.ListThreads,
    Jido.Connect.Gmail.Actions.GetThread,
    Jido.Connect.Gmail.Actions.ListHistory,
    Jido.Connect.Gmail.Actions.GetAttachment,
    Jido.Connect.Gmail.Actions.SendMessage,
    Jido.Connect.Gmail.Actions.CreateDraft,
    Jido.Connect.Gmail.Actions.SendDraft,
    Jido.Connect.Gmail.Actions.CreateLabel,
    Jido.Connect.Gmail.Actions.ApplyMessageLabels,
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

    def send_draft(%{draft_id: "draft123"}, "token") do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "sent-draft123",
         thread_id: "thread123",
         label_ids: ["SENT"]
       })}
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
    assert "https://www.googleapis.com/auth/gmail.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.send" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.compose" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/gmail.modify" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "google.gmail.profile.get",
             "google.gmail.labels.list",
             "google.gmail.messages.list",
             "google.gmail.message.get",
             "google.gmail.threads.list",
             "google.gmail.thread.get",
             "google.gmail.history.list",
             "google.gmail.message.attachment.get",
             "google.gmail.message.send",
             "google.gmail.draft.create",
             "google.gmail.draft.send",
             "google.gmail.label.create",
             "google.gmail.message.labels.apply",
             "google.gmail.watch.start",
             "google.gmail.watch.stop"
           ]

    send_action = Enum.find(spec.actions, &(&1.id == "google.gmail.message.send"))
    assert send_action.risk == :external_write
    assert send_action.confirmation == :required_for_ai

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
      send_pack: :google_gmail_send
    )
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
    {context, lease} = context_and_lease()

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
    {context, lease} = context_and_lease()

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
    {context, lease} = context_and_lease(scopes: modify_scopes())

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

  test "label mutations require modify scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/gmail.modify"]
            }} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.label.create",
               %{name: "Customers"},
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
        fields: %{access_token: "token", gmail_client: FakeGmailClient},
        scopes: scopes
      })

    {context, lease}
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

  defp modify_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.modify"
    ]
  end
end
