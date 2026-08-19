defmodule Jido.Connect.SlackTest do
  use ExUnit.Case

  alias Jido.Connect

  defmodule FakeSlackClient do
    def list_channels(%{types: "public_channel"}, "token") do
      {:ok,
       %{
         channels: [
           %{
             id: "C123",
             name: "general",
             is_archived: false,
             is_private: false,
             is_member: true
           }
         ],
         next_cursor: ""
       }}
    end

    def list_channels(%{types: "private_channel"}, "token") do
      {:ok,
       %{
         channels: [
           %{
             id: "G123",
             name: "private",
             is_archived: false,
             is_private: true,
             is_member: true
           }
         ],
         next_cursor: ""
       }}
    end

    def get_thread_replies(
          %{channel: "C123", ts: "1700000000.000100", limit: 100},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         thread_ts: "1700000000.000100",
         messages: [
           %{
             type: "message",
             user: "U123",
             text: "Root",
             ts: "1700000000.000100",
             reply_count: 1,
             latest_reply: "1700000001.000200"
           },
           %{
             type: "message",
             user: "U456",
             text: "Reply",
             ts: "1700000001.000200",
             thread_ts: "1700000000.000100"
           }
         ],
         next_cursor: "next",
         has_more: true
       }}
    end

    def get_thread_replies(
          %{channel: "G123", ts: "1700000000.000100"},
          "token"
        ) do
      {:ok,
       %{
         channel: "G123",
         thread_ts: "1700000000.000100",
         messages: [],
         next_cursor: "",
         has_more: false
       }}
    end

    def search_messages(
          %{
            query: "deploy in:#general from:<@U123> after:2026-04-01 has:link",
            sort: "timestamp",
            sort_dir: "desc",
            count: 10,
            page: 2,
            highlight: true
          },
          "token"
        ) do
      {:ok,
       %{
         query: "deploy in:#general from:<@U123> after:2026-04-01 has:link",
         messages: [
           %{
             type: "message",
             user: "U123",
             username: "ada",
             text: "deploy finished",
             ts: "1700000000.000100",
             channel: %{id: "C123", name: "general", is_private: false},
             permalink: "https://example.slack.com/archives/C123/p1700000000000100",
             team: "T123"
           }
         ],
         total_count: 1,
         pagination: %{page: 2, per_page: 10, total_count: 1},
         paging: %{page: 2, count: 10, total: 1},
         next_cursor: "next"
       }}
    end

    def search_files(
          %{
            query: "report in:#general from:<@U123> after:2026-04-01 has:pdf",
            sort: "timestamp",
            sort_dir: "desc",
            count: 10,
            page: 2,
            highlight: true
          },
          "token"
        ) do
      {:ok,
       %{
         query: "report in:#general from:<@U123> after:2026-04-01 has:pdf",
         files: [
           %{
             id: "F123",
             created: 1_700_000_000,
             timestamp: 1_700_000_000,
             name: "report.pdf",
             title: "Report",
             mimetype: "application/pdf",
             filetype: "pdf",
             pretty_type: "PDF",
             user: "U123",
             size: 1234,
             permalink: "https://example.slack.com/files/U123/F123/report.pdf",
             channels: ["C123"],
             comments_count: 1
           }
         ],
         total_count: 1,
         pagination: %{page: 2, per_page: 10, total_count: 1},
         paging: %{page: 2, count: 10, total: 1},
         next_cursor: "next"
       }}
    end

    def list_conversation_members(%{channel: "C123", limit: 100}, "token") do
      {:ok,
       %{
         channel: "C123",
         members: ["U123", "U456"],
         next_cursor: "next"
       }}
    end

    def list_conversation_members(%{channel: "G123"}, "token") do
      {:ok,
       %{
         channel: "G123",
         members: ["U789"],
         next_cursor: ""
       }}
    end

    def get_conversation_info(%{channel: "C123"}, "token") do
      {:ok,
       %{
         channel: "C123",
         conversation: %{
           "id" => "C123",
           "name" => "general",
           "is_channel" => true,
           "is_private" => false
         }
       }}
    end

    def get_conversation_info(%{channel: "G123"}, "token") do
      {:ok,
       %{
         channel: "G123",
         conversation: %{
           "id" => "G123",
           "name" => "private",
           "is_group" => true,
           "is_private" => true
         }
       }}
    end

    def get_conversation_info(%{channel: "D123"}, "token") do
      {:ok,
       %{
         channel: "D123",
         conversation: %{
           "id" => "D123",
           "is_im" => true,
           "user" => "U123"
         }
       }}
    end

    def get_conversation_info(%{channel: "GMP123"}, "token") do
      {:ok,
       %{
         channel: "GMP123",
         conversation: %{
           "id" => "GMP123",
           "is_mpim" => true,
           "name" => "mpdm-user-1--user-2-1"
         }
       }}
    end

    def create_channel(%{name: "project-updates", is_private: false}, "token") do
      {:ok,
       %{
         channel: %{
           id: "C999",
           name: "project-updates",
           is_archived: false,
           is_private: false,
           is_member: true
         }
       }}
    end

    def create_channel(%{name: "secret-updates", is_private: true}, "token") do
      {:ok,
       %{
         channel: %{
           id: "G999",
           name: "secret-updates",
           is_archived: false,
           is_private: true,
           is_member: true
         }
       }}
    end

    def archive_conversation(%{channel: "C999"}, "token") do
      {:ok, %{channel: "C999"}}
    end

    def archive_conversation(%{channel: "G999"}, "token") do
      {:ok, %{channel: "G999"}}
    end

    def unarchive_conversation(%{channel: "C999"}, "token") do
      {:ok, %{channel: "C999"}}
    end

    def unarchive_conversation(%{channel: "G999"}, "token") do
      {:ok, %{channel: "G999"}}
    end

    def rename_conversation(%{channel: "C999", name: "renamed-channel"}, "token") do
      {:ok,
       %{
         channel: %{
           id: "C999",
           name: "renamed-channel",
           is_archived: false,
           is_private: false,
           is_member: true
         }
       }}
    end

    def rename_conversation(%{channel: "G999", name: "renamed-private"}, "token") do
      {:ok,
       %{
         channel: %{
           id: "G999",
           name: "renamed-private",
           is_archived: false,
           is_private: true,
           is_member: true
         }
       }}
    end

    def invite_conversation(%{channel: "C999", users: ["U123", "U456"], force: false}, "token") do
      {:ok,
       %{
         channel: %{
           id: "C999",
           name: "project-updates",
           is_archived: false,
           is_private: false,
           is_member: true
         },
         invited_users: ["U123", "U456"],
         failed_users: [],
         partial_failure: false
       }}
    end

    def invite_conversation(%{channel: "C999", users: ["U123", "U404"], force: true}, "token") do
      {:ok,
       %{
         channel: %{id: "C999"},
         invited_users: ["U123"],
         failed_users: [%{user: "U404", error: "user_not_found", ok: false}],
         partial_failure: true
       }}
    end

    def kick_conversation(%{channel: "C999", user: "U123"}, "token") do
      {:ok, %{channel: "C999", user: "U123"}}
    end

    def kick_conversation(%{channel: "G999", user: "U123"}, "token") do
      {:ok, %{channel: "G999", user: "U123"}}
    end

    def open_conversation(%{users: ["U123"]}, "token") do
      {:ok,
       %{
         channel: "D123",
         conversation: %{
           id: "D123",
           is_im: true,
           is_open: true,
           user: "U123"
         }
       }}
    end

    def open_conversation(%{users: ["U123", "U456"]}, "token") do
      {:ok,
       %{
         channel: "GMP123",
         conversation: %{
           id: "GMP123",
           is_mpim: true,
           is_private: true,
           is_open: true,
           users: ["U123", "U456"]
         }
       }}
    end

    def open_conversation(%{channel: "D123"}, "token") do
      {:ok,
       %{
         channel: "D123",
         conversation: %{
           id: "D123",
           is_im: true,
           is_open: true,
           user: "U123"
         }
       }}
    end

    def post_message(
          %{channel: "C123", text: "Hello", reply_broadcast: false},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         ts: "1700000000.000100",
         message: %{text: "Hello"}
       }}
    end

    def post_ephemeral(
          %{channel: "C123", user: "U123", text: "Only you can see this"},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         user: "U123",
         message_ts: "1700000000.000200"
       }}
    end

    def schedule_message(
          %{channel: "C123", text: "Later", post_at: post_at, reply_broadcast: false},
          "token"
        )
        when is_integer(post_at) do
      {:ok,
       %{
         channel: "C123",
         scheduled_message_id: "Q123",
         post_at: post_at,
         message: %{text: "Later", type: "delayed_message"}
       }}
    end

    def delete_scheduled_message(
          %{channel: "C123", scheduled_message_id: "Q123"},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         scheduled_message_id: "Q123"
       }}
    end

    def update_message(
          %{channel: "C123", ts: "1700000000.000100", text: "Updated"},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         ts: "1700000000.000100",
         message: %{text: "Updated"}
       }}
    end

    def delete_message(
          %{channel: "C123", ts: "1700000000.000100"},
          token
        )
        when token in ["token", "user-token"] do
      {:ok,
       %{
         channel: "C123",
         ts: "1700000000.000100"
       }}
    end

    def add_reaction(
          %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         timestamp: "1700000000.000100",
         name: "thumbsup"
       }}
    end

    def remove_reaction(
          %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"},
          "token"
        ) do
      {:ok,
       %{
         channel: "C123",
         timestamp: "1700000000.000100",
         name: "thumbsup"
       }}
    end

    def get_reactions(
          %{channel: "C123", timestamp: "1700000000.000100"},
          "token"
        ) do
      {:ok,
       %{
         type: "message",
         channel: "C123",
         timestamp: "1700000000.000100",
         message: %{
           "type" => "message",
           "text" => "Hello",
           "ts" => "1700000000.000100",
           "reactions" => [%{"name" => "thumbsup", "count" => 1, "users" => ["U123"]}]
         },
         reactions: [%{"name" => "thumbsup", "count" => 1, "users" => ["U123"]}]
       }}
    end

    def get_reactions(%{file: "F123"}, "token") do
      {:ok,
       %{
         type: "file",
         file_id: "F123",
         file: %{
           "id" => "F123",
           "name" => "report.txt",
           "reactions" => [%{"name" => "eyes", "count" => 2, "users" => ["U123", "U456"]}]
         },
         reactions: [%{"name" => "eyes", "count" => 2, "users" => ["U123", "U456"]}]
       }}
    end

    def list_pins(%{channel: "C123"}, "token") do
      {:ok,
       %{
         channel: "C123",
         items: [
           %{
             type: "message",
             channel: "C123",
             timestamp: "1700000000.000100",
             created: 1_700_000_001,
             created_by: "U123",
             message: %{"text" => "Pinned", "ts" => "1700000000.000100"}
           },
           %{
             type: "file",
             created: 1_700_000_002,
             created_by: "U456",
             file: %{"id" => "F123", "name" => "report.txt"}
           }
         ]
       }}
    end

    def add_pin(%{channel: "C123", timestamp: "1700000000.000100"}, "token") do
      {:ok,
       %{
         type: "message",
         channel: "C123",
         timestamp: "1700000000.000100"
       }}
    end

    def remove_pin(%{channel: "C123", timestamp: "1700000000.000100"}, "token") do
      {:ok,
       %{
         type: "message",
         channel: "C123",
         timestamp: "1700000000.000100"
       }}
    end

    def upload_file(
          %{
            channel_id: "C123",
            filename: "report.txt",
            content: "Hello file",
            title: "Report",
            initial_comment: "Here is the report"
          },
          "token"
        ) do
      {:ok,
       %{
         file_id: "F123",
         files: [%{"id" => "F123", "title" => "Report"}]
       }}
    end

    def share_file(
          %{
            file_id: "F123",
            channels: "C123,C456",
            title: "Report",
            initial_comment: "Here is the report"
          },
          "token"
        ) do
      {:ok,
       %{
         file_id: "F123",
         files: [%{"id" => "F123", "title" => "Report"}]
       }}
    end

    def delete_file(%{file_id: "F123"}, "token") do
      {:ok, %{file_id: "F123"}}
    end

    def auth_test("token") do
      {:ok,
       %{
         "team_id" => "T123",
         "team" => "Demo",
         "url" => "https://demo.slack.com/",
         "user_id" => "U123",
         "user" => "demo-user",
         "bot_id" => "B123",
         "enterprise_id" => "E123",
         "is_enterprise_install" => true
       }}
    end

    def list_users(%{limit: 100}, "token") do
      {:ok,
       %{
         users: [
           %{
             id: "U123",
             team_id: "T123",
             name: "ada",
             real_name: "Ada Lovelace",
             deleted: false,
             is_bot: false,
             is_app_user: false,
             profile: %{"email" => "ada@example.com"}
           }
         ],
         next_cursor: "next"
       }}
    end

    def user_info(%{user: "U123"}, "token") do
      {:ok,
       %{
         user: %{
           id: "U123",
           team_id: "T123",
           name: "ada",
           real_name: "Ada Lovelace",
           deleted: false,
           is_bot: false,
           is_app_user: false,
           profile: %{
             email: "ada@example.com",
             display_name: "ada",
             real_name: "Ada Lovelace"
           }
         }
       }}
    end

    def user_info(%{user: "B123"}, "token") do
      {:ok,
       %{
         user: %{
           id: "B123",
           team_id: "T123",
           name: "build-bot",
           real_name: "Build Bot",
           deleted: false,
           is_bot: true,
           is_app_user: false,
           profile: %{
             bot_id: "B999",
             display_name: "build-bot",
             real_name: "Build Bot"
           }
         }
       }}
    end

    def lookup_user_by_email(%{email: "ada@example.com"}, "token") do
      {:ok,
       %{
         user: %{
           id: "U123",
           team_id: "T123",
           name: "ada",
           real_name: "Ada Lovelace",
           deleted: false,
           is_bot: false,
           is_app_user: false,
           profile: %{
             email: "ada@example.com",
             display_name: "ada",
             real_name: "Ada Lovelace"
           }
         }
       }}
    end

    def lookup_user_by_email(%{email: "app@example.com"}, "token") do
      {:ok,
       %{
         user: %{
           id: "UAPP",
           team_id: "T123",
           name: "workflow-app",
           real_name: "Workflow App",
           deleted: false,
           is_bot: false,
           is_app_user: true,
           profile: %{}
         }
       }}
    end

    def lookup_user_by_email(%{email: "bot@example.com"}, "token") do
      {:ok,
       %{
         user: %{
           id: "B123",
           team_id: "T123",
           name: "build-bot",
           real_name: "Build Bot",
           deleted: false,
           is_bot: true,
           is_app_user: false,
           profile: nil
         }
       }}
    end

    def team_info(%{team_id: "T123"}, "token") do
      {:ok,
       %{
         team: %{
           "id" => "T123",
           "name" => "Demo",
           "domain" => "demo",
           "email_domain" => "demo.example",
           "enterprise_id" => "E123",
           "enterprise_name" => "Example Enterprise"
         }
       }}
    end
  end

  test "Slack integration declares first actions" do
    spec = Jido.Connect.Slack.integration()

    assert spec.id == :slack
    assert spec.package == :jido_connect_slack
    assert spec.tags == [:chat, :collaboration, :messaging]
    assert [%{id: :workspace_access}] = spec.policies

    assert {:ok,
            %{
              id: "slack.channel.list",
              resource: :channel,
              verb: :list,
              policies: [:workspace_access],
              mutation?: false
            }} =
             Connect.action(spec, "slack.channel.list")

    assert {:ok,
            %{
              id: "slack.thread.replies",
              resource: :thread,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["channels:history"],
              auth_profile: :bot,
              auth_profiles: [:bot, :user],
              mutation?: false
            }} =
             Connect.action(spec, "slack.thread.replies")

    assert {:ok,
            %{
              id: "slack.conversation.info",
              resource: :conversation,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["channels:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.conversation.info")

    assert {:ok,
            %{
              id: "slack.channel.create",
              resource: :channel,
              verb: :create,
              policies: [:workspace_access],
              scopes: ["channels:manage"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.channel.create")

    assert {:ok,
            %{
              id: "slack.channel.archive",
              resource: :channel,
              verb: :archive,
              policies: [:workspace_access],
              scopes: ["channels:manage"],
              mutation?: true,
              confirmation: :always,
              risk: :destructive
            }} =
             Connect.action(spec, "slack.channel.archive")

    assert {:ok,
            %{
              id: "slack.channel.unarchive",
              resource: :channel,
              verb: :unarchive,
              policies: [:workspace_access],
              scopes: ["channels:manage"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.channel.unarchive")

    assert {:ok,
            %{
              id: "slack.channel.rename",
              resource: :channel,
              verb: :update,
              policies: [:workspace_access],
              scopes: ["channels:manage"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.channel.rename")

    assert {:ok,
            %{
              id: "slack.conversation.invite",
              resource: :conversation_member,
              verb: :create,
              policies: [:workspace_access],
              scopes: ["channels:manage"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.conversation.invite")

    assert {:ok,
            %{
              id: "slack.conversation.kick",
              resource: :conversation_member,
              verb: :delete,
              policies: [:workspace_access],
              scopes: ["channels:manage"],
              mutation?: true,
              confirmation: :always,
              risk: :destructive
            }} =
             Connect.action(spec, "slack.conversation.kick")

    assert {:ok,
            %{
              id: "slack.conversation.open",
              resource: :conversation,
              verb: :create,
              policies: [:workspace_access],
              scopes: ["im:write"],
              mutation?: true
            }} =
             Connect.action(spec, "slack.conversation.open")

    assert {:ok,
            %{
              id: "slack.conversation.members",
              resource: :conversation_member,
              verb: :list,
              policies: [:workspace_access],
              scopes: ["channels:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.conversation.members")

    assert {:ok,
            %{
              id: "slack.message.post",
              auth_profile: :bot,
              auth_profiles: [:bot, :user],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.message.post")

    assert {:ok,
            %{
              id: "slack.message.search",
              resource: :message,
              verb: :search,
              policies: [:workspace_access],
              scopes: ["search:read"],
              auth_profile: :user,
              auth_profiles: [:user],
              mutation?: false
            }} =
             Connect.action(spec, "slack.message.search")

    assert {:ok,
            %{
              id: "slack.message.post_ephemeral",
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.message.post_ephemeral")

    assert {:ok,
            %{
              id: "slack.message.schedule",
              resource: :message,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.message.schedule")

    assert {:ok,
            %{
              id: "slack.message.unschedule",
              resource: :message,
              verb: :cancel,
              mutation?: true,
              confirmation: :always,
              risk: :destructive
            }} =
             Connect.action(spec, "slack.message.unschedule")

    assert {:ok, %{id: "slack.message.update", mutation?: true, confirmation: :required_for_ai}} =
             Connect.action(spec, "slack.message.update")

    assert {:ok,
            %{
              id: "slack.message.delete",
              mutation?: true,
              confirmation: :always,
              risk: :destructive,
              auth_profile: :bot,
              auth_profiles: [:bot, :user]
            }} =
             Connect.action(spec, "slack.message.delete")

    assert {:ok,
            %{
              id: "slack.reaction.list",
              resource: :reaction,
              verb: :list,
              policies: [:workspace_access],
              scopes: ["reactions:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.reaction.list")

    assert {:ok,
            %{
              id: "slack.reaction.add",
              resource: :reaction,
              verb: :create,
              policies: [:workspace_access],
              scopes: ["reactions:write"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.reaction.add")

    assert {:ok,
            %{
              id: "slack.reaction.remove",
              resource: :reaction,
              verb: :delete,
              policies: [:workspace_access],
              scopes: ["reactions:write"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.reaction.remove")

    assert {:ok,
            %{
              id: "slack.pin.list",
              resource: :pin,
              verb: :list,
              policies: [:workspace_access],
              scopes: ["pins:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.pin.list")

    assert {:ok,
            %{
              id: "slack.pin.add",
              resource: :pin,
              verb: :create,
              policies: [:workspace_access],
              scopes: ["pins:write"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.pin.add")

    assert {:ok,
            %{
              id: "slack.pin.remove",
              resource: :pin,
              verb: :delete,
              policies: [:workspace_access],
              scopes: ["pins:write"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.pin.remove")

    assert {:ok,
            %{
              id: "slack.file.search",
              resource: :file,
              verb: :search,
              policies: [:workspace_access],
              scopes: ["search:read"],
              auth_profile: :user,
              auth_profiles: [:user],
              mutation?: false
            }} =
             Connect.action(spec, "slack.file.search")

    assert {:ok,
            %{
              id: "slack.file.share",
              resource: :file,
              verb: :share,
              policies: [:workspace_access],
              scopes: ["files:write"],
              mutation?: true,
              confirmation: :required_for_ai
            }} =
             Connect.action(spec, "slack.file.share")

    assert {:ok,
            %{
              id: "slack.auth.test",
              resource: :auth,
              verb: :read,
              policies: [:workspace_access],
              auth_profile: :bot,
              auth_profiles: [:bot, :user],
              mutation?: false
            }} =
             Connect.action(spec, "slack.auth.test")

    assert {:ok,
            %{
              id: "slack.team.info",
              resource: :team,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["team:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.team.info")

    assert {:ok,
            %{
              id: "slack.user.list",
              resource: :user,
              verb: :list,
              policies: [:workspace_access],
              scopes: ["users:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.user.list")

    assert {:ok,
            %{
              id: "slack.user.info",
              resource: :user,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["users:read"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.user.info")

    assert {:ok,
            %{
              id: "slack.user.lookup_by_email",
              resource: :user,
              verb: :read,
              policies: [:workspace_access],
              scopes: ["users:read.email"],
              mutation?: false
            }} =
             Connect.action(spec, "slack.user.lookup_by_email")

    assert {:ok,
            %{
              id: "slack.event.app_mention",
              kind: :webhook,
              resource: :message,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["app_mentions:read"],
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.app_mention")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :channel,
             :channel_type,
             :user,
             :text,
             :ts,
             :thread_ts
           ]

    assert {:ok,
            %{
              id: "slack.event.message.channels",
              kind: :webhook,
              resource: :message,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["channels:history"],
              dedupe: %{key: [:team_id, :channel, :ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.message.channels")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :channel,
             :channel_type,
             :user,
             :text,
             :ts,
             :thread_ts,
             :event_ts
           ]

    assert {:ok,
            %{
              id: "slack.event.message.groups",
              kind: :webhook,
              resource: :message,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["groups:history"],
              dedupe: %{key: [:team_id, :channel, :ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.message.groups")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :channel,
             :channel_type,
             :user,
             :text,
             :ts,
             :thread_ts,
             :event_ts
           ]

    assert {:ok,
            %{
              id: "slack.event.message.im",
              kind: :webhook,
              resource: :message,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["im:history"],
              dedupe: %{key: [:team_id, :channel, :ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.message.im")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :channel,
             :channel_type,
             :user,
             :user_team,
             :source_team,
             :text,
             :ts,
             :thread_ts,
             :event_ts,
             :sender,
             :conversation
           ]

    assert {:ok,
            %{
              id: "slack.event.message.mpim",
              kind: :webhook,
              resource: :message,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["mpim:history"],
              dedupe: %{key: [:team_id, :channel, :ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.message.mpim")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :channel,
             :channel_type,
             :user,
             :user_team,
             :source_team,
             :text,
             :ts,
             :thread_ts,
             :event_ts,
             :sender,
             :conversation
           ]

    assert {:ok,
            %{
              id: "slack.event.message.thread_reply",
              kind: :webhook,
              resource: :message,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["channels:history", "groups:history", "im:history", "mpim:history"],
              dedupe: %{key: [:team_id, :channel, :thread_ts, :ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.message.thread_reply")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :channel,
             :channel_type,
             :user,
             :user_team,
             :source_team,
             :text,
             :ts,
             :thread_ts,
             :event_ts,
             :sender,
             :conversation
           ]

    assert {:ok,
            %{
              id: "slack.event.reaction_added",
              kind: :webhook,
              resource: :reaction,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["reactions:read"],
              dedupe: %{key: [:team_id, :user, :reaction, :item_type, :channel, :ts, :event_ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.reaction_added")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :user,
             :reaction,
             :item_user,
             :item,
             :item_type,
             :channel,
             :ts,
             :file,
             :file_comment,
             :event_ts,
             :actor,
             :item_owner
           ]

    assert {:ok,
            %{
              id: "slack.event.reaction_removed",
              kind: :webhook,
              resource: :reaction,
              verb: :watch,
              policies: [:workspace_access],
              scopes: ["reactions:read"],
              dedupe: %{key: [:team_id, :user, :reaction, :item_type, :channel, :ts, :event_ts]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.reaction_removed")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :user,
             :reaction,
             :item_user,
             :item,
             :item_type,
             :channel,
             :ts,
             :file,
             :file_comment,
             :event_ts,
             :actor,
             :item_owner
           ]

    assert {:ok,
            %{
              id: "slack.event.app_uninstalled",
              kind: :webhook,
              resource: :app,
              verb: :watch,
              policies: [:workspace_access],
              scopes: [],
              dedupe: %{key: [:team_id, :api_app_id, :event_id]},
              verification: %{
                kind: :slack_signed_request,
                signature_header: "x-slack-signature",
                timestamp_header: "x-slack-request-timestamp"
              }
            } = trigger} = Connect.trigger(spec, "slack.event.app_uninstalled")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :api_app_id,
             :event_time,
             :authorizations
           ]

    assert {:ok,
            %{
              id: "slack.event.tokens_revoked",
              kind: :webhook,
              resource: :token,
              verb: :watch,
              policies: [:workspace_access],
              scopes: [],
              dedupe: %{key: [:team_id, :api_app_id, :event_id]}
            } = trigger} = Connect.trigger(spec, "slack.event.tokens_revoked")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :api_app_id,
             :event_time,
             :tokens,
             :oauth_user_ids,
             :bot_user_ids
           ]

    assert {:ok,
            %{
              id: "slack.event.scope_denied",
              kind: :webhook,
              resource: :scope,
              verb: :watch,
              policies: [:workspace_access],
              scopes: [],
              dedupe: %{key: [:team_id, :api_app_id, :event_id]}
            } = trigger} = Connect.trigger(spec, "slack.event.scope_denied")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :api_app_id,
             :event_time,
             :scope,
             :scopes,
             :user,
             :trigger_id,
             :event_ts
           ]

    assert {:ok,
            %{
              id: "slack.event.app_home_opened",
              kind: :webhook,
              resource: :app_home,
              verb: :watch,
              policies: [:workspace_access],
              scopes: [],
              dedupe: %{key: [:team_id, :user, :channel, :event_ts]}
            } = trigger} = Connect.trigger(spec, "slack.event.app_home_opened")

    assert Enum.map(trigger.signal, & &1.name) == [
             :team_id,
             :event_id,
             :api_app_id,
             :user,
             :channel,
             :tab,
             :view,
             :event_ts,
             :actor,
             :conversation
           ]
  end

  test "Slack catalog entry exposes setup, auth, and runtime capabilities" do
    entry = Connect.Catalog.entry(Jido.Connect.Slack)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_slack
    assert MapSet.member?(features, :oauth2)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :slack_app_manifest)
    assert MapSet.member?(features, :signed_request_verification)
  end

  test "Slack integration compiles generated Jido modules" do
    assert Application.get_env(:jido_connect_slack, :jido_connect_providers) == [
             Jido.Connect.Slack
           ]

    assert Jido.Connect.Slack.jido_action_modules() == [
             Jido.Connect.Slack.Actions.ListChannels,
             Jido.Connect.Slack.Actions.GetThreadReplies,
             Jido.Connect.Slack.Actions.GetConversationInfo,
             Jido.Connect.Slack.Actions.CreateChannel,
             Jido.Connect.Slack.Actions.ArchiveChannel,
             Jido.Connect.Slack.Actions.UnarchiveChannel,
             Jido.Connect.Slack.Actions.RenameChannel,
             Jido.Connect.Slack.Actions.InviteUsers,
             Jido.Connect.Slack.Actions.KickUser,
             Jido.Connect.Slack.Actions.OpenConversation,
             Jido.Connect.Slack.Actions.ListConversationMembers,
             Jido.Connect.Slack.Actions.SearchFiles,
             Jido.Connect.Slack.Actions.UploadFile,
             Jido.Connect.Slack.Actions.ShareFile,
             Jido.Connect.Slack.Actions.DeleteFile,
             Jido.Connect.Slack.Actions.AuthTest,
             Jido.Connect.Slack.Actions.TeamInfo,
             Jido.Connect.Slack.Actions.PostMessage,
             Jido.Connect.Slack.Actions.SearchMessages,
             Jido.Connect.Slack.Actions.PostEphemeral,
             Jido.Connect.Slack.Actions.ScheduleMessage,
             Jido.Connect.Slack.Actions.UnscheduleMessage,
             Jido.Connect.Slack.Actions.UpdateMessage,
             Jido.Connect.Slack.Actions.DeleteMessage,
             Jido.Connect.Slack.Actions.ListPins,
             Jido.Connect.Slack.Actions.AddPin,
             Jido.Connect.Slack.Actions.RemovePin,
             Jido.Connect.Slack.Actions.GetPresence,
             Jido.Connect.Slack.Actions.SetPresence,
             Jido.Connect.Slack.Actions.SetStatus,
             Jido.Connect.Slack.Actions.ClearStatus,
             Jido.Connect.Slack.Actions.ListEmoji,
             Jido.Connect.Slack.Actions.ListUnreadMessages,
             Jido.Connect.Slack.Actions.MarkConversationRead,
             Jido.Connect.Slack.Actions.ListReactions,
             Jido.Connect.Slack.Actions.AddReaction,
             Jido.Connect.Slack.Actions.RemoveReaction,
             Jido.Connect.Slack.Actions.ListUsers,
             Jido.Connect.Slack.Actions.UserInfo,
             Jido.Connect.Slack.Actions.LookupUserByEmail
           ]

    assert Jido.Connect.Slack.jido_sensor_modules() == [
             Jido.Connect.Slack.Sensors.AppMention,
             Jido.Connect.Slack.Sensors.PublicChannelMessage,
             Jido.Connect.Slack.Sensors.PrivateChannelMessage,
             Jido.Connect.Slack.Sensors.DirectMessage,
             Jido.Connect.Slack.Sensors.MultiPersonDirectMessage,
             Jido.Connect.Slack.Sensors.ThreadReply,
             Jido.Connect.Slack.Sensors.ReactionAdded,
             Jido.Connect.Slack.Sensors.ReactionRemoved,
             Jido.Connect.Slack.Sensors.ChannelCreated,
             Jido.Connect.Slack.Sensors.ChannelRename,
             Jido.Connect.Slack.Sensors.ChannelArchive,
             Jido.Connect.Slack.Sensors.ChannelUnarchive,
             Jido.Connect.Slack.Sensors.MemberJoinedChannel,
             Jido.Connect.Slack.Sensors.MemberLeftChannel,
             Jido.Connect.Slack.Sensors.FileCreated,
             Jido.Connect.Slack.Sensors.FileShared,
             Jido.Connect.Slack.Sensors.FilePublic,
             Jido.Connect.Slack.Sensors.FileDeleted,
             Jido.Connect.Slack.Sensors.FileChange,
             Jido.Connect.Slack.Sensors.AppUninstalled,
             Jido.Connect.Slack.Sensors.TokensRevoked,
             Jido.Connect.Slack.Sensors.ScopeDenied,
             Jido.Connect.Slack.Sensors.AppHomeOpened
           ]

    assert Jido.Connect.Slack.jido_plugin_module() == Jido.Connect.Slack.Plugin

    assert %Connect.Catalog.Manifest{
             id: :slack,
             package: :jido_connect_slack,
             generated_modules: %{
               actions: [
                 Jido.Connect.Slack.Actions.ListChannels,
                 Jido.Connect.Slack.Actions.GetThreadReplies,
                 Jido.Connect.Slack.Actions.GetConversationInfo,
                 Jido.Connect.Slack.Actions.CreateChannel,
                 Jido.Connect.Slack.Actions.ArchiveChannel,
                 Jido.Connect.Slack.Actions.UnarchiveChannel,
                 Jido.Connect.Slack.Actions.RenameChannel,
                 Jido.Connect.Slack.Actions.InviteUsers,
                 Jido.Connect.Slack.Actions.KickUser,
                 Jido.Connect.Slack.Actions.OpenConversation,
                 Jido.Connect.Slack.Actions.ListConversationMembers,
                 Jido.Connect.Slack.Actions.SearchFiles,
                 Jido.Connect.Slack.Actions.UploadFile,
                 Jido.Connect.Slack.Actions.ShareFile,
                 Jido.Connect.Slack.Actions.DeleteFile,
                 Jido.Connect.Slack.Actions.AuthTest,
                 Jido.Connect.Slack.Actions.TeamInfo,
                 Jido.Connect.Slack.Actions.PostMessage,
                 Jido.Connect.Slack.Actions.SearchMessages,
                 Jido.Connect.Slack.Actions.PostEphemeral,
                 Jido.Connect.Slack.Actions.ScheduleMessage,
                 Jido.Connect.Slack.Actions.UnscheduleMessage,
                 Jido.Connect.Slack.Actions.UpdateMessage,
                 Jido.Connect.Slack.Actions.DeleteMessage,
                 Jido.Connect.Slack.Actions.ListPins,
                 Jido.Connect.Slack.Actions.AddPin,
                 Jido.Connect.Slack.Actions.RemovePin,
                 Jido.Connect.Slack.Actions.GetPresence,
                 Jido.Connect.Slack.Actions.SetPresence,
                 Jido.Connect.Slack.Actions.SetStatus,
                 Jido.Connect.Slack.Actions.ClearStatus,
                 Jido.Connect.Slack.Actions.ListEmoji,
                 Jido.Connect.Slack.Actions.ListUnreadMessages,
                 Jido.Connect.Slack.Actions.MarkConversationRead,
                 Jido.Connect.Slack.Actions.ListReactions,
                 Jido.Connect.Slack.Actions.AddReaction,
                 Jido.Connect.Slack.Actions.RemoveReaction,
                 Jido.Connect.Slack.Actions.ListUsers,
                 Jido.Connect.Slack.Actions.UserInfo,
                 Jido.Connect.Slack.Actions.LookupUserByEmail
               ],
               sensors: [
                 Jido.Connect.Slack.Sensors.AppMention,
                 Jido.Connect.Slack.Sensors.PublicChannelMessage,
                 Jido.Connect.Slack.Sensors.PrivateChannelMessage,
                 Jido.Connect.Slack.Sensors.DirectMessage,
                 Jido.Connect.Slack.Sensors.MultiPersonDirectMessage,
                 Jido.Connect.Slack.Sensors.ThreadReply,
                 Jido.Connect.Slack.Sensors.ReactionAdded,
                 Jido.Connect.Slack.Sensors.ReactionRemoved,
                 Jido.Connect.Slack.Sensors.ChannelCreated,
                 Jido.Connect.Slack.Sensors.ChannelRename,
                 Jido.Connect.Slack.Sensors.ChannelArchive,
                 Jido.Connect.Slack.Sensors.ChannelUnarchive,
                 Jido.Connect.Slack.Sensors.MemberJoinedChannel,
                 Jido.Connect.Slack.Sensors.MemberLeftChannel,
                 Jido.Connect.Slack.Sensors.FileCreated,
                 Jido.Connect.Slack.Sensors.FileShared,
                 Jido.Connect.Slack.Sensors.FilePublic,
                 Jido.Connect.Slack.Sensors.FileDeleted,
                 Jido.Connect.Slack.Sensors.FileChange,
                 Jido.Connect.Slack.Sensors.AppUninstalled,
                 Jido.Connect.Slack.Sensors.TokensRevoked,
                 Jido.Connect.Slack.Sensors.ScopeDenied,
                 Jido.Connect.Slack.Sensors.AppHomeOpened
               ],
               plugin: Jido.Connect.Slack.Plugin
             }
           } = Jido.Connect.Slack.jido_connect_manifest()

    assert {:module, Jido.Connect.Slack.Actions.ListChannels} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListChannels)

    assert {:module, Jido.Connect.Slack.Actions.GetThreadReplies} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.GetThreadReplies)

    assert {:module, Jido.Connect.Slack.Actions.CreateChannel} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.CreateChannel)

    assert {:module, Jido.Connect.Slack.Actions.ArchiveChannel} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ArchiveChannel)

    assert {:module, Jido.Connect.Slack.Actions.UnarchiveChannel} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UnarchiveChannel)

    assert {:module, Jido.Connect.Slack.Actions.RenameChannel} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.RenameChannel)

    assert {:module, Jido.Connect.Slack.Actions.KickUser} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.KickUser)

    assert {:module, Jido.Connect.Slack.Actions.SearchMessages} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.SearchMessages)

    assert {:module, Jido.Connect.Slack.Actions.ListConversationMembers} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListConversationMembers)

    assert {:module, Jido.Connect.Slack.Actions.SearchFiles} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.SearchFiles)

    assert {:module, Jido.Connect.Slack.Actions.UploadFile} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UploadFile)

    assert {:module, Jido.Connect.Slack.Actions.ShareFile} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ShareFile)

    assert {:module, Jido.Connect.Slack.Actions.AuthTest} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.AuthTest)

    assert {:module, Jido.Connect.Slack.Actions.TeamInfo} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.TeamInfo)

    assert {:module, Jido.Connect.Slack.Actions.ListUsers} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListUsers)

    assert {:module, Jido.Connect.Slack.Actions.UserInfo} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UserInfo)

    assert {:module, Jido.Connect.Slack.Actions.LookupUserByEmail} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.LookupUserByEmail)

    assert {:module, Jido.Connect.Slack.Actions.UpdateMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UpdateMessage)

    assert {:module, Jido.Connect.Slack.Actions.PostEphemeral} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.PostEphemeral)

    assert {:module, Jido.Connect.Slack.Actions.ScheduleMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ScheduleMessage)

    assert {:module, Jido.Connect.Slack.Actions.UnscheduleMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.UnscheduleMessage)

    assert {:module, Jido.Connect.Slack.Actions.DeleteMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.DeleteMessage)

    assert {:module, Jido.Connect.Slack.Actions.AddPin} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.AddPin)

    assert {:module, Jido.Connect.Slack.Actions.RemovePin} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.RemovePin)

    assert {:module, Jido.Connect.Slack.Actions.ListReactions} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.ListReactions)

    assert {:module, Jido.Connect.Slack.Actions.AddReaction} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.AddReaction)

    assert {:module, Jido.Connect.Slack.Actions.RemoveReaction} =
             Code.ensure_loaded(Jido.Connect.Slack.Actions.RemoveReaction)

    assert {:module, Jido.Connect.Slack.Plugin} =
             Code.ensure_loaded(Jido.Connect.Slack.Plugin)

    assert {:module, Jido.Connect.Slack.Sensors.AppMention} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.AppMention)

    assert {:module, Jido.Connect.Slack.Sensors.PublicChannelMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.PublicChannelMessage)

    assert {:module, Jido.Connect.Slack.Sensors.PrivateChannelMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.PrivateChannelMessage)

    assert {:module, Jido.Connect.Slack.Sensors.DirectMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.DirectMessage)

    assert {:module, Jido.Connect.Slack.Sensors.MultiPersonDirectMessage} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.MultiPersonDirectMessage)

    assert {:module, Jido.Connect.Slack.Sensors.ThreadReply} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.ThreadReply)

    assert {:module, Jido.Connect.Slack.Sensors.ReactionAdded} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.ReactionAdded)

    assert {:module, Jido.Connect.Slack.Sensors.ReactionRemoved} =
             Code.ensure_loaded(Jido.Connect.Slack.Sensors.ReactionRemoved)

    assert function_exported?(Jido.Connect.Slack.Actions.ListChannels, :run, 2)
    assert function_exported?(Jido.Connect.Slack.Sensors.AppMention, :handle_event, 2)
    assert function_exported?(Jido.Connect.Slack.Sensors.PublicChannelMessage, :handle_event, 2)
    assert function_exported?(Jido.Connect.Slack.Sensors.PrivateChannelMessage, :handle_event, 2)
    assert function_exported?(Jido.Connect.Slack.Sensors.DirectMessage, :handle_event, 2)

    assert function_exported?(
             Jido.Connect.Slack.Sensors.MultiPersonDirectMessage,
             :handle_event,
             2
           )

    assert function_exported?(Jido.Connect.Slack.Sensors.ThreadReply, :handle_event, 2)
    assert function_exported?(Jido.Connect.Slack.Sensors.ReactionAdded, :handle_event, 2)
    assert function_exported?(Jido.Connect.Slack.Sensors.ReactionRemoved, :handle_event, 2)

    assert function_exported?(Jido.Connect.Slack.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.Slack.Actions.PostMessage.jido_connect_projection()

    assert projection.action_id == "slack.message.post"
    assert projection.label == "Post message"
    assert projection.resource == :message
    assert projection.verb == :create
    assert projection.policies == [:workspace_access]

    assert Enum.map(projection.input, & &1.name) == [
             :channel,
             :text,
             :thread_ts,
             :reply_broadcast
           ]

    assert projection.risk == :write
    assert projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.PostMessage.name() == "slack_message_post"

    search_projection = Jido.Connect.Slack.Actions.SearchMessages.jido_connect_projection()

    assert search_projection.action_id == "slack.message.search"
    assert search_projection.label == "Search messages"
    assert search_projection.resource == :message
    assert search_projection.verb == :search
    assert search_projection.scopes == ["search:read"]
    assert search_projection.auth_profiles == [:user]

    assert Enum.map(search_projection.input, & &1.name) == [
             :query,
             :in,
             :from,
             :before,
             :after,
             :on,
             :has,
             :sort,
             :sort_dir,
             :count,
             :page,
             :cursor,
             :highlight,
             :team_id
           ]

    assert Enum.map(search_projection.output, & &1.name) == [
             :query,
             :messages,
             :total_count,
             :pagination,
             :paging,
             :next_cursor
           ]

    assert search_projection.risk == :read
    assert search_projection.confirmation == :none
    assert Jido.Connect.Slack.Actions.SearchMessages.name() == "slack_message_search"

    search_files_projection = Jido.Connect.Slack.Actions.SearchFiles.jido_connect_projection()

    assert search_files_projection.action_id == "slack.file.search"
    assert search_files_projection.label == "Search files"
    assert search_files_projection.resource == :file
    assert search_files_projection.verb == :search
    assert search_files_projection.scopes == ["search:read"]
    assert search_files_projection.auth_profiles == [:user]

    assert Enum.map(search_files_projection.input, & &1.name) == [
             :query,
             :in,
             :from,
             :before,
             :after,
             :on,
             :has,
             :sort,
             :sort_dir,
             :count,
             :page,
             :cursor,
             :highlight,
             :team_id
           ]

    assert Enum.map(search_files_projection.output, & &1.name) == [
             :query,
             :files,
             :total_count,
             :pagination,
             :paging,
             :next_cursor
           ]

    assert search_files_projection.risk == :read
    assert search_files_projection.confirmation == :none
    assert Jido.Connect.Slack.Actions.SearchFiles.name() == "slack_file_search"

    ephemeral_projection = Jido.Connect.Slack.Actions.PostEphemeral.jido_connect_projection()

    assert ephemeral_projection.action_id == "slack.message.post_ephemeral"
    assert ephemeral_projection.label == "Post ephemeral message"
    assert ephemeral_projection.resource == :message
    assert ephemeral_projection.verb == :create
    assert ephemeral_projection.scopes == ["chat:write"]

    assert Enum.map(ephemeral_projection.input, & &1.name) == [
             :channel,
             :user,
             :text,
             :thread_ts,
             :blocks
           ]

    assert Enum.map(ephemeral_projection.output, & &1.name) == [
             :channel,
             :user,
             :message_ts
           ]

    assert ephemeral_projection.risk == :write
    assert ephemeral_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.PostEphemeral.name() == "slack_message_post_ephemeral"

    schedule_projection = Jido.Connect.Slack.Actions.ScheduleMessage.jido_connect_projection()

    assert schedule_projection.action_id == "slack.message.schedule"
    assert schedule_projection.label == "Schedule message"
    assert schedule_projection.resource == :message
    assert schedule_projection.verb == :create
    assert schedule_projection.scopes == ["chat:write"]

    assert Enum.map(schedule_projection.input, & &1.name) == [
             :channel,
             :text,
             :post_at,
             :thread_ts,
             :reply_broadcast,
             :blocks
           ]

    assert Enum.map(schedule_projection.output, & &1.name) == [
             :channel,
             :scheduled_message_id,
             :post_at,
             :message
           ]

    assert schedule_projection.risk == :write
    assert schedule_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.ScheduleMessage.name() == "slack_message_schedule"

    unschedule_projection = Jido.Connect.Slack.Actions.UnscheduleMessage.jido_connect_projection()

    assert unschedule_projection.action_id == "slack.message.unschedule"
    assert unschedule_projection.label == "Unschedule message"
    assert unschedule_projection.resource == :message
    assert unschedule_projection.verb == :cancel
    assert unschedule_projection.scopes == ["chat:write"]

    assert Enum.map(unschedule_projection.input, & &1.name) == [
             :channel,
             :scheduled_message_id
           ]

    assert Enum.map(unschedule_projection.output, & &1.name) == [
             :channel,
             :scheduled_message_id
           ]

    assert unschedule_projection.risk == :destructive
    assert unschedule_projection.confirmation == :always
    assert Jido.Connect.Slack.Actions.UnscheduleMessage.name() == "slack_message_unschedule"

    update_projection = Jido.Connect.Slack.Actions.UpdateMessage.jido_connect_projection()

    assert update_projection.action_id == "slack.message.update"
    assert update_projection.label == "Update message"
    assert update_projection.resource == :message
    assert update_projection.verb == :update

    assert Enum.map(update_projection.input, & &1.name) == [
             :channel,
             :ts,
             :text,
             :blocks
           ]

    assert update_projection.risk == :write
    assert update_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.UpdateMessage.name() == "slack_message_update"

    delete_projection = Jido.Connect.Slack.Actions.DeleteMessage.jido_connect_projection()

    assert delete_projection.action_id == "slack.message.delete"
    assert delete_projection.label == "Delete message"
    assert delete_projection.resource == :message
    assert delete_projection.verb == :delete

    assert Enum.map(delete_projection.input, & &1.name) == [
             :channel,
             :ts
           ]

    assert Enum.map(delete_projection.output, & &1.name) == [
             :channel,
             :ts
           ]

    assert delete_projection.risk == :destructive
    assert delete_projection.confirmation == :always
    assert delete_projection.auth_profile == :bot
    assert delete_projection.auth_profiles == [:bot, :user]
    assert Jido.Connect.Slack.Actions.DeleteMessage.name() == "slack_message_delete"

    list_reactions_projection = Jido.Connect.Slack.Actions.ListReactions.jido_connect_projection()

    assert list_reactions_projection.action_id == "slack.reaction.list"
    assert list_reactions_projection.label == "List reactions"
    assert list_reactions_projection.resource == :reaction
    assert list_reactions_projection.verb == :list
    assert list_reactions_projection.scopes == ["reactions:read"]

    assert Enum.map(list_reactions_projection.input, & &1.name) == [
             :channel,
             :timestamp,
             :file,
             :file_comment,
             :full
           ]

    assert Enum.map(list_reactions_projection.output, & &1.name) == [
             :type,
             :channel,
             :timestamp,
             :file_id,
             :file_comment_id,
             :message,
             :file,
             :file_comment,
             :reactions
           ]

    assert list_reactions_projection.risk == :read
    assert list_reactions_projection.confirmation == :none
    assert Jido.Connect.Slack.Actions.ListReactions.name() == "slack_reaction_list"

    reaction_projection = Jido.Connect.Slack.Actions.AddReaction.jido_connect_projection()

    assert reaction_projection.action_id == "slack.reaction.add"
    assert reaction_projection.label == "Add reaction"
    assert reaction_projection.resource == :reaction
    assert reaction_projection.verb == :create
    assert reaction_projection.scopes == ["reactions:write"]

    assert Enum.map(reaction_projection.input, & &1.name) == [
             :channel,
             :timestamp,
             :name
           ]

    assert Enum.map(reaction_projection.output, & &1.name) == [
             :channel,
             :timestamp,
             :name
           ]

    assert reaction_projection.risk == :write
    assert reaction_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.AddReaction.name() == "slack_reaction_add"

    remove_reaction_projection =
      Jido.Connect.Slack.Actions.RemoveReaction.jido_connect_projection()

    assert remove_reaction_projection.action_id == "slack.reaction.remove"
    assert remove_reaction_projection.label == "Remove reaction"
    assert remove_reaction_projection.resource == :reaction
    assert remove_reaction_projection.verb == :delete
    assert remove_reaction_projection.scopes == ["reactions:write"]

    assert Enum.map(remove_reaction_projection.input, & &1.name) == [
             :channel,
             :timestamp,
             :name
           ]

    assert Enum.map(remove_reaction_projection.output, & &1.name) == [
             :channel,
             :timestamp,
             :name
           ]

    assert remove_reaction_projection.risk == :write
    assert remove_reaction_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.RemoveReaction.name() == "slack_reaction_remove"

    list_pins_projection = Jido.Connect.Slack.Actions.ListPins.jido_connect_projection()

    assert list_pins_projection.action_id == "slack.pin.list"
    assert list_pins_projection.label == "List pinned items"
    assert list_pins_projection.resource == :pin
    assert list_pins_projection.verb == :list
    assert list_pins_projection.scopes == ["pins:read"]

    assert Enum.map(list_pins_projection.input, & &1.name) == [
             :channel
           ]

    assert Enum.map(list_pins_projection.output, & &1.name) == [
             :channel,
             :items
           ]

    assert list_pins_projection.risk == :read
    assert list_pins_projection.confirmation == :none
    assert Jido.Connect.Slack.Actions.ListPins.name() == "slack_pin_list"

    pin_projection = Jido.Connect.Slack.Actions.AddPin.jido_connect_projection()

    assert pin_projection.action_id == "slack.pin.add"
    assert pin_projection.label == "Pin message"
    assert pin_projection.resource == :pin
    assert pin_projection.verb == :create
    assert pin_projection.scopes == ["pins:write"]

    assert Enum.map(pin_projection.input, & &1.name) == [
             :channel,
             :timestamp
           ]

    assert Enum.map(pin_projection.output, & &1.name) == [
             :type,
             :channel,
             :timestamp
           ]

    assert pin_projection.risk == :write
    assert pin_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.AddPin.name() == "slack_pin_add"

    remove_pin_projection = Jido.Connect.Slack.Actions.RemovePin.jido_connect_projection()

    assert remove_pin_projection.action_id == "slack.pin.remove"
    assert remove_pin_projection.label == "Unpin message"
    assert remove_pin_projection.resource == :pin
    assert remove_pin_projection.verb == :delete
    assert remove_pin_projection.scopes == ["pins:write"]

    assert Enum.map(remove_pin_projection.input, & &1.name) == [
             :channel,
             :timestamp
           ]

    assert Enum.map(remove_pin_projection.output, & &1.name) == [
             :type,
             :channel,
             :timestamp
           ]

    assert remove_pin_projection.risk == :write
    assert remove_pin_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.RemovePin.name() == "slack_pin_remove"

    upload_projection = Jido.Connect.Slack.Actions.UploadFile.jido_connect_projection()

    assert upload_projection.action_id == "slack.file.upload"
    assert upload_projection.label == "Upload file"
    assert upload_projection.resource == :file
    assert upload_projection.verb == :upload
    assert upload_projection.scopes == ["files:write"]

    assert Enum.map(upload_projection.input, & &1.name) == [
             :channel_id,
             :filename,
             :content,
             :title,
             :initial_comment,
             :thread_ts,
             :alt_txt,
             :snippet_type
           ]

    assert Enum.map(upload_projection.output, & &1.name) == [
             :file_id,
             :files
           ]

    assert upload_projection.risk == :write
    assert upload_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.UploadFile.name() == "slack_file_upload"

    share_projection = Jido.Connect.Slack.Actions.ShareFile.jido_connect_projection()

    assert share_projection.action_id == "slack.file.share"
    assert share_projection.label == "Share file"
    assert share_projection.resource == :file
    assert share_projection.verb == :share
    assert share_projection.scopes == ["files:write"]

    assert Enum.map(share_projection.input, & &1.name) == [
             :file_id,
             :channels,
             :title,
             :initial_comment,
             :thread_ts
           ]

    assert Enum.map(share_projection.output, & &1.name) == [
             :file_id,
             :files
           ]

    assert share_projection.risk == :write
    assert share_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.ShareFile.name() == "slack_file_share"

    delete_file_projection = Jido.Connect.Slack.Actions.DeleteFile.jido_connect_projection()

    assert delete_file_projection.action_id == "slack.file.delete"
    assert delete_file_projection.label == "Delete file"
    assert delete_file_projection.resource == :file
    assert delete_file_projection.verb == :delete
    assert delete_file_projection.scopes == ["files:write"]

    assert Enum.map(delete_file_projection.input, & &1.name) == [
             :file_id
           ]

    assert Enum.map(delete_file_projection.output, & &1.name) == [
             :file_id
           ]

    assert delete_file_projection.risk == :destructive
    assert delete_file_projection.confirmation == :always
    assert Jido.Connect.Slack.Actions.DeleteFile.name() == "slack_file_delete"

    list_projection = Jido.Connect.Slack.Actions.ListChannels.jido_connect_projection()
    assert list_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    replies_projection = Jido.Connect.Slack.Actions.GetThreadReplies.jido_connect_projection()
    assert replies_projection.action_id == "slack.thread.replies"
    assert replies_projection.resource == :thread
    assert replies_projection.verb == :read
    assert replies_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(replies_projection.input, & &1.name) == [
             :channel,
             :ts,
             :conversation_type,
             :limit,
             :cursor,
             :oldest,
             :latest,
             :inclusive
           ]

    assert Enum.map(replies_projection.output, & &1.name) == [
             :channel,
             :thread_ts,
             :messages,
             :reply_count,
             :latest_reply,
             :next_cursor,
             :has_more
           ]

    members_projection =
      Jido.Connect.Slack.Actions.ListConversationMembers.jido_connect_projection()

    assert members_projection.action_id == "slack.conversation.members"
    assert members_projection.resource == :conversation_member
    assert members_projection.verb == :list
    assert members_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(members_projection.input, & &1.name) == [
             :channel,
             :conversation_type,
             :limit,
             :cursor
           ]

    assert Enum.map(members_projection.output, & &1.name) == [
             :channel,
             :members,
             :next_cursor
           ]

    conversation_info_projection =
      Jido.Connect.Slack.Actions.GetConversationInfo.jido_connect_projection()

    assert conversation_info_projection.action_id == "slack.conversation.info"
    assert conversation_info_projection.resource == :conversation
    assert conversation_info_projection.verb == :read
    assert conversation_info_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(conversation_info_projection.input, & &1.name) == [
             :channel,
             :conversation_type,
             :include_locale
           ]

    assert Enum.map(conversation_info_projection.output, & &1.name) == [
             :channel,
             :conversation
           ]

    create_channel_projection =
      Jido.Connect.Slack.Actions.CreateChannel.jido_connect_projection()

    assert create_channel_projection.action_id == "slack.channel.create"
    assert create_channel_projection.resource == :channel
    assert create_channel_projection.verb == :create
    assert create_channel_projection.scopes == ["channels:manage"]
    assert create_channel_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(create_channel_projection.input, & &1.name) == [
             :name,
             :is_private,
             :team_id
           ]

    assert Enum.map(create_channel_projection.output, & &1.name) == [
             :channel
           ]

    archive_channel_projection =
      Jido.Connect.Slack.Actions.ArchiveChannel.jido_connect_projection()

    assert archive_channel_projection.action_id == "slack.channel.archive"
    assert archive_channel_projection.label == "Archive channel"
    assert archive_channel_projection.resource == :channel
    assert archive_channel_projection.verb == :archive
    assert archive_channel_projection.scopes == ["channels:manage"]
    assert archive_channel_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(archive_channel_projection.input, & &1.name) == [
             :channel,
             :conversation_type
           ]

    assert Enum.map(archive_channel_projection.output, & &1.name) == [
             :channel
           ]

    assert archive_channel_projection.risk == :destructive
    assert archive_channel_projection.confirmation == :always
    assert Jido.Connect.Slack.Actions.ArchiveChannel.name() == "slack_channel_archive"

    unarchive_channel_projection =
      Jido.Connect.Slack.Actions.UnarchiveChannel.jido_connect_projection()

    assert unarchive_channel_projection.action_id == "slack.channel.unarchive"
    assert unarchive_channel_projection.label == "Unarchive channel"
    assert unarchive_channel_projection.resource == :channel
    assert unarchive_channel_projection.verb == :unarchive
    assert unarchive_channel_projection.scopes == ["channels:manage"]
    assert unarchive_channel_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(unarchive_channel_projection.input, & &1.name) == [
             :channel,
             :conversation_type
           ]

    assert Enum.map(unarchive_channel_projection.output, & &1.name) == [
             :channel
           ]

    assert unarchive_channel_projection.risk == :write
    assert unarchive_channel_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.UnarchiveChannel.name() == "slack_channel_unarchive"

    rename_channel_projection =
      Jido.Connect.Slack.Actions.RenameChannel.jido_connect_projection()

    assert rename_channel_projection.action_id == "slack.channel.rename"
    assert rename_channel_projection.label == "Rename channel"
    assert rename_channel_projection.resource == :channel
    assert rename_channel_projection.verb == :update
    assert rename_channel_projection.scopes == ["channels:manage"]
    assert rename_channel_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(rename_channel_projection.input, & &1.name) == [
             :channel,
             :name,
             :conversation_type
           ]

    assert Enum.map(rename_channel_projection.output, & &1.name) == [
             :channel
           ]

    assert rename_channel_projection.risk == :write
    assert rename_channel_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.RenameChannel.name() == "slack_channel_rename"

    invite_users_projection =
      Jido.Connect.Slack.Actions.InviteUsers.jido_connect_projection()

    assert invite_users_projection.action_id == "slack.conversation.invite"
    assert invite_users_projection.label == "Invite users to channel"
    assert invite_users_projection.resource == :conversation_member
    assert invite_users_projection.verb == :create
    assert invite_users_projection.scopes == ["channels:manage"]
    assert invite_users_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(invite_users_projection.input, & &1.name) == [
             :channel,
             :users,
             :force,
             :conversation_type
           ]

    assert Enum.map(invite_users_projection.output, & &1.name) == [
             :channel,
             :invited_users,
             :failed_users,
             :partial_failure
           ]

    assert invite_users_projection.risk == :write
    assert invite_users_projection.confirmation == :required_for_ai
    assert Jido.Connect.Slack.Actions.InviteUsers.name() == "slack_conversation_invite"

    kick_user_projection =
      Jido.Connect.Slack.Actions.KickUser.jido_connect_projection()

    assert kick_user_projection.action_id == "slack.conversation.kick"
    assert kick_user_projection.label == "Remove user from channel"
    assert kick_user_projection.resource == :conversation_member
    assert kick_user_projection.verb == :delete
    assert kick_user_projection.scopes == ["channels:manage"]
    assert kick_user_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(kick_user_projection.input, & &1.name) == [
             :channel,
             :user,
             :conversation_type
           ]

    assert Enum.map(kick_user_projection.output, & &1.name) == [
             :channel,
             :user
           ]

    assert kick_user_projection.risk == :destructive
    assert kick_user_projection.confirmation == :always
    assert Jido.Connect.Slack.Actions.KickUser.name() == "slack_conversation_kick"

    open_conversation_projection =
      Jido.Connect.Slack.Actions.OpenConversation.jido_connect_projection()

    assert open_conversation_projection.action_id == "slack.conversation.open"
    assert open_conversation_projection.resource == :conversation
    assert open_conversation_projection.verb == :create
    assert open_conversation_projection.scopes == ["im:write"]
    assert open_conversation_projection.scope_resolver == Jido.Connect.Slack.ScopeResolver

    assert Enum.map(open_conversation_projection.input, & &1.name) == [
             :users,
             :channel,
             :return_im,
             :prevent_creation
           ]

    assert Enum.map(open_conversation_projection.output, & &1.name) == [
             :channel,
             :conversation
           ]

    auth_projection = Jido.Connect.Slack.Actions.AuthTest.jido_connect_projection()
    assert auth_projection.action_id == "slack.auth.test"
    assert auth_projection.resource == :auth
    assert auth_projection.verb == :read

    team_projection = Jido.Connect.Slack.Actions.TeamInfo.jido_connect_projection()
    assert team_projection.action_id == "slack.team.info"

    assert Enum.map(team_projection.output, & &1.name) == [
             :team_id,
             :name,
             :domain,
             :email_domain,
             :enterprise_id,
             :enterprise_name,
             :team
           ]

    user_projection = Jido.Connect.Slack.Actions.ListUsers.jido_connect_projection()
    assert user_projection.action_id == "slack.user.list"
    assert user_projection.resource == :user
    assert user_projection.verb == :list

    assert Enum.map(user_projection.input, & &1.name) == [
             :limit,
             :cursor,
             :team_id,
             :include_locale
           ]

    assert Enum.map(user_projection.output, & &1.name) == [:users, :next_cursor]

    user_info_projection = Jido.Connect.Slack.Actions.UserInfo.jido_connect_projection()
    assert user_info_projection.action_id == "slack.user.info"
    assert user_info_projection.resource == :user
    assert user_info_projection.verb == :read

    assert Enum.map(user_info_projection.input, & &1.name) == [
             :user,
             :include_locale
           ]

    assert Enum.map(user_info_projection.output, & &1.name) == [
             :user_id,
             :team_id,
             :name,
             :real_name,
             :tz,
             :deleted,
             :is_bot,
             :is_app_user,
             :user_type,
             :bot_id,
             :updated,
             :profile,
             :user
           ]

    lookup_user_projection =
      Jido.Connect.Slack.Actions.LookupUserByEmail.jido_connect_projection()

    assert lookup_user_projection.action_id == "slack.user.lookup_by_email"
    assert lookup_user_projection.resource == :user
    assert lookup_user_projection.verb == :read
    assert lookup_user_projection.scopes == ["users:read.email"]

    assert Enum.map(lookup_user_projection.input, & &1.name) == [
             :email
           ]

    assert Enum.map(lookup_user_projection.output, & &1.name) == [
             :user_id,
             :team_id,
             :name,
             :real_name,
             :tz,
             :deleted,
             :is_bot,
             :is_app_user,
             :user_type,
             :bot_id,
             :updated,
             :profile,
             :user
           ]
  end

  test "generated list channels action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channels: [%{id: "C123", name: "general"}], next_cursor: ""}} =
             Jido.Connect.Slack.Actions.ListChannels.run(
               %{types: "public_channel"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "list channels resolves scopes from requested conversation types" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["groups:read"]}} =
             Jido.Connect.Slack.Actions.ListChannels.run(
               %{types: "private_channel"},
               %{integration_context: context, credential_lease: lease}
             )

    private_context = %{
      context
      | connection: %{
          context.connection
          | scopes: ["channels:read", "groups:read", "chat:write"]
        }
    }

    assert {:ok, %{channels: [%{id: "G123", name: "private"}], next_cursor: ""}} =
             Jido.Connect.Slack.Actions.ListChannels.run(
               %{types: "private_channel"},
               %{integration_context: private_context, credential_lease: lease}
             )
  end

  test "generated list conversation members action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channel: "C123", members: ["U123", "U456"], next_cursor: "next"}} =
             Jido.Connect.Slack.Actions.ListConversationMembers.run(
               %{channel: "C123", limit: 100},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "list conversation members resolves scopes from conversation type" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:read"]
            }} =
             Jido.Connect.Slack.Actions.ListConversationMembers.run(
               %{channel: "G123"},
               %{integration_context: context, credential_lease: lease}
             )

    private_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes ++ ["groups:read"]
        }
    }

    assert {:ok, %{channel: "G123", members: ["U789"]}} =
             Jido.Connect.Slack.Actions.ListConversationMembers.run(
               %{channel: "G123"},
               %{integration_context: private_context, credential_lease: lease}
             )
  end

  test "generated get conversation info action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              conversation: %{
                "id" => "C123",
                "name" => "general",
                "is_channel" => true
              }
            }} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "C123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "get conversation info resolves scopes from conversation type" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:read"]
            }} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "G123"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["im:read"]
            }} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "D123"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["mpim:read"]
            }} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "GMP123", conversation_type: "mpim"},
               %{integration_context: context, credential_lease: lease}
             )

    expanded_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes ++ ["groups:read", "im:read", "mpim:read"]
        }
    }

    assert {:ok, %{channel: "G123", conversation: %{"is_private" => true}}} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "G123"},
               %{integration_context: expanded_context, credential_lease: lease}
             )

    assert {:ok, %{channel: "D123", conversation: %{"is_im" => true}}} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "D123"},
               %{integration_context: expanded_context, credential_lease: lease}
             )

    assert {:ok, %{channel: "GMP123", conversation: %{"is_mpim" => true}}} =
             Jido.Connect.Slack.Actions.GetConversationInfo.run(
               %{channel: "GMP123", conversation_type: "mpim"},
               %{integration_context: expanded_context, credential_lease: lease}
             )
  end

  test "generated create channel action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: %{
                id: "C999",
                name: "project-updates",
                is_private: false
              }
            }} =
             Jido.Connect.Slack.Actions.CreateChannel.run(
               %{name: "project-updates", is_private: false},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "create channel resolves scopes for public and private channels" do
    {context, lease} = context_and_lease()

    no_manage_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes -- ["channels:manage", "groups:write"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["channels:manage"]
            }} =
             Jido.Connect.Slack.Actions.CreateChannel.run(
               %{name: "project-updates", is_private: false},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:write"]
            }} =
             Jido.Connect.Slack.Actions.CreateChannel.run(
               %{name: "secret-updates", is_private: true},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:ok, %{channel: %{id: "G999", is_private: true}}} =
             Jido.Connect.Slack.Actions.CreateChannel.run(
               %{name: "secret-updates", is_private: true},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated archive channel action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channel: "C999"}} =
             Jido.Connect.Slack.Actions.ArchiveChannel.run(
               %{channel: "C999"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "archive channel resolves scopes from conversation type" do
    {context, lease} = context_and_lease()

    no_manage_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes -- ["channels:manage", "groups:write"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["channels:manage"]
            }} =
             Jido.Connect.Slack.Actions.ArchiveChannel.run(
               %{channel: "C999"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:write"]
            }} =
             Jido.Connect.Slack.Actions.ArchiveChannel.run(
               %{channel: "G999"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:ok, %{channel: "G999"}} =
             Jido.Connect.Slack.Actions.ArchiveChannel.run(
               %{channel: "G999"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated unarchive channel action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channel: "C999"}} =
             Jido.Connect.Slack.Actions.UnarchiveChannel.run(
               %{channel: "C999"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "unarchive channel resolves scopes from conversation type" do
    {context, lease} = context_and_lease()

    no_manage_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes -- ["channels:manage", "groups:write"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["channels:manage"]
            }} =
             Jido.Connect.Slack.Actions.UnarchiveChannel.run(
               %{channel: "C999"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:write"]
            }} =
             Jido.Connect.Slack.Actions.UnarchiveChannel.run(
               %{channel: "G999"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:ok, %{channel: "G999"}} =
             Jido.Connect.Slack.Actions.UnarchiveChannel.run(
               %{channel: "G999"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated rename channel action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channel: %{id: "C999", name: "renamed-channel"}}} =
             Jido.Connect.Slack.Actions.RenameChannel.run(
               %{channel: "C999", name: "renamed-channel"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "rename channel resolves scopes from conversation type" do
    {context, lease} = context_and_lease()

    no_manage_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes -- ["channels:manage", "groups:write"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["channels:manage"]
            }} =
             Jido.Connect.Slack.Actions.RenameChannel.run(
               %{channel: "C999", name: "renamed-channel"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:write"]
            }} =
             Jido.Connect.Slack.Actions.RenameChannel.run(
               %{channel: "G999", name: "renamed-private"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:ok, %{channel: %{id: "G999", name: "renamed-private"}}} =
             Jido.Connect.Slack.Actions.RenameChannel.run(
               %{channel: "G999", name: "renamed-private"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "create channel validates Slack channel names" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :name}
            }} =
             Jido.Connect.Slack.Actions.CreateChannel.run(
               %{name: "Invalid Name", is_private: false},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "rename channel validates Slack channel names" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :name}
            }} =
             Jido.Connect.Slack.Actions.RenameChannel.run(
               %{channel: "C999", name: "Invalid Name"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated invite users action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: %{
                id: "C999",
                name: "project-updates",
                is_archived: false,
                is_private: false,
                is_member: true
              },
              invited_users: ["U123", "U456"],
              failed_users: [],
              partial_failure: false
            }} =
             Jido.Connect.Slack.Actions.InviteUsers.run(
               %{channel: "C999", users: ["U123", "U456"], force: false},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "invite users validates Slack user lists" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :users}
            }} =
             Jido.Connect.Slack.Actions.InviteUsers.run(
               %{channel: "C999", users: []},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :users}
            }} =
             Jido.Connect.Slack.Actions.InviteUsers.run(
               %{channel: "C999", users: ["not-a-user"]},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "invite users returns partial failures when Slack continues valid users" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: %{id: "C999"},
              invited_users: ["U123"],
              failed_users: [%{user: "U404", error: "user_not_found", ok: false}],
              partial_failure: true
            }} =
             Jido.Connect.Slack.Actions.InviteUsers.run(
               %{channel: "C999", users: ["U123", "U404"], force: true},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated kick user action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{channel: "C999", user: "U123"}} =
             Jido.Connect.Slack.Actions.KickUser.run(
               %{channel: "C999", user: "U123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "kick user validates Slack channel and user ids" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.KickUser.run(
               %{channel: "D123", user: "U123"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :user}
            }} =
             Jido.Connect.Slack.Actions.KickUser.run(
               %{channel: "C999", user: "not-a-user"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "kick user resolves scopes from conversation type" do
    {context, lease} = context_and_lease()

    no_manage_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes -- ["channels:manage", "groups:write"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["channels:manage"]
            }} =
             Jido.Connect.Slack.Actions.KickUser.run(
               %{channel: "C999", user: "U123"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:write"]
            }} =
             Jido.Connect.Slack.Actions.KickUser.run(
               %{channel: "G999", user: "U123"},
               %{integration_context: no_manage_context, credential_lease: lease}
             )

    assert {:ok, %{channel: "G999", user: "U123"}} =
             Jido.Connect.Slack.Actions.KickUser.run(
               %{channel: "G999", user: "U123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated open conversation action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "D123",
              conversation: %{
                id: "D123",
                is_im: true,
                is_open: true,
                user: "U123"
              }
            }} =
             Jido.Connect.Slack.Actions.OpenConversation.run(
               %{users: ["U123"]},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "open conversation resolves scopes from DM or MPIM target" do
    {context, lease} = context_and_lease()

    no_write_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes -- ["im:write", "mpim:write"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["im:write"]
            }} =
             Jido.Connect.Slack.Actions.OpenConversation.run(
               %{users: ["U123"]},
               %{integration_context: no_write_context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["mpim:write"]
            }} =
             Jido.Connect.Slack.Actions.OpenConversation.run(
               %{users: ["U123", "U456"]},
               %{integration_context: no_write_context, credential_lease: lease}
             )

    assert {:ok, %{channel: "GMP123", conversation: %{is_mpim: true}}} =
             Jido.Connect.Slack.Actions.OpenConversation.run(
               %{users: ["U123", "U456"]},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated post ephemeral action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              user: "U123",
              message_ts: "1700000000.000200"
            }} =
             Jido.Connect.Slack.Actions.PostEphemeral.run(
               %{channel: "C123", user: "U123", text: "Only you can see this"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated post ephemeral action validates channel and user ids" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "general",
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.PostEphemeral.run(
               %{channel: "general", user: "U123", text: "Only you can see this"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "ada",
              details: %{field: :user}
            }} =
             Jido.Connect.Slack.Actions.PostEphemeral.run(
               %{channel: "C123", user: "ada", text: "Only you can see this"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated get thread replies action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              thread_ts: "1700000000.000100",
              messages: [
                %{text: "Root", ts: "1700000000.000100", reply_count: 1},
                %{text: "Reply", thread_ts: "1700000000.000100"}
              ],
              reply_count: 1,
              latest_reply: "1700000001.000200",
              next_cursor: "next",
              has_more: true
            }} =
             Jido.Connect.Slack.Actions.GetThreadReplies.run(
               %{channel: "C123", ts: "1700000000.000100", limit: 100},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "get thread replies resolves history scopes from conversation type" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["groups:history"]
            }} =
             Jido.Connect.Slack.Actions.GetThreadReplies.run(
               %{channel: "G123", ts: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )

    private_context = %{
      context
      | connection: %{
          context.connection
          | scopes: context.connection.scopes ++ ["groups:history"]
        }
    }

    assert {:ok, %{channel: "G123", thread_ts: "1700000000.000100"}} =
             Jido.Connect.Slack.Actions.GetThreadReplies.run(
               %{channel: "G123", ts: "1700000000.000100"},
               %{integration_context: private_context, credential_lease: lease}
             )
  end

  test "generated post message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100",
              message: %{text: "Hello"}
            }} =
             Jido.Connect.Slack.Actions.PostMessage.run(
               %{channel: "C123", text: "Hello"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated search messages action delegates with query helpers and pagination" do
    {context, lease} = context_and_lease(profile: :user)

    assert {:ok,
            %{
              query: "deploy in:#general from:<@U123> after:2026-04-01 has:link",
              messages: [
                %{
                  type: "message",
                  user: "U123",
                  username: "ada",
                  text: "deploy finished",
                  ts: "1700000000.000100",
                  channel: %{id: "C123", name: "general", is_private: false},
                  permalink: "https://example.slack.com/archives/C123/p1700000000000100",
                  team: "T123"
                }
              ],
              total_count: 1,
              pagination: %{page: 2, per_page: 10, total_count: 1},
              paging: %{page: 2, count: 10, total: 1},
              next_cursor: "next"
            }} =
             Jido.Connect.Slack.Actions.SearchMessages.run(
               %{
                 query: "deploy",
                 in: "#general",
                 from: "<@U123>",
                 after: "2026-04-01",
                 has: "link",
                 sort: "timestamp",
                 sort_dir: "desc",
                 count: 10,
                 page: 2,
                 highlight: true
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated search files action delegates with query helpers and normalized output" do
    {context, lease} = context_and_lease(profile: :user)

    assert {:ok,
            %{
              query: "report in:#general from:<@U123> after:2026-04-01 has:pdf",
              files: [
                %{
                  id: "F123",
                  created: 1_700_000_000,
                  timestamp: 1_700_000_000,
                  name: "report.pdf",
                  title: "Report",
                  mimetype: "application/pdf",
                  filetype: "pdf",
                  pretty_type: "PDF",
                  user: "U123",
                  size: 1234,
                  permalink: "https://example.slack.com/files/U123/F123/report.pdf",
                  channels: ["C123"],
                  comments_count: 1
                }
              ],
              total_count: 1,
              pagination: %{page: 2, per_page: 10, total_count: 1},
              paging: %{page: 2, count: 10, total: 1},
              next_cursor: "next"
            }} =
             Jido.Connect.Slack.Actions.SearchFiles.run(
               %{
                 query: "report",
                 in: "#general",
                 from: "<@U123>",
                 after: "2026-04-01",
                 has: "pdf",
                 sort: "timestamp",
                 sort_dir: "desc",
                 count: 10,
                 page: 2,
                 highlight: true
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated schedule message action delegates through integration runtime" do
    {context, lease} = context_and_lease()
    post_at = System.system_time(:second) + 60

    assert {:ok,
            %{
              channel: "C123",
              scheduled_message_id: "Q123",
              post_at: ^post_at,
              message: %{text: "Later", type: "delayed_message"}
            }} =
             Jido.Connect.Slack.Actions.ScheduleMessage.run(
               %{channel: "C123", text: "Later", post_at: post_at},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated schedule message action validates post_at" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: 1,
              details: %{field: :post_at}
            }} =
             Jido.Connect.Slack.Actions.ScheduleMessage.run(
               %{channel: "C123", text: "Later", post_at: 1},
               %{integration_context: context, credential_lease: lease}
             )

    post_at = System.system_time(:second) + 121 * 24 * 60 * 60

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: ^post_at,
              details: %{field: :post_at}
            }} =
             Jido.Connect.Slack.Actions.ScheduleMessage.run(
               %{channel: "C123", text: "Later", post_at: post_at},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated unschedule message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              scheduled_message_id: "Q123"
            }} =
             Jido.Connect.Slack.Actions.UnscheduleMessage.run(
               %{channel: "C123", scheduled_message_id: "Q123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated update message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100",
              message: %{text: "Updated"}
            }} =
             Jido.Connect.Slack.Actions.UpdateMessage.run(
               %{channel: "C123", ts: "1700000000.000100", text: "Updated"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated delete message action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100"
            }} =
             Jido.Connect.Slack.Actions.DeleteMessage.run(
               %{channel: "C123", ts: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated delete message action accepts Slack user-token connections" do
    {context, lease} = context_and_lease(profile: :user, access_token: "user-token")

    assert {:ok,
            %{
              channel: "C123",
              ts: "1700000000.000100"
            }} =
             Jido.Connect.Slack.Actions.DeleteMessage.run(
               %{channel: "C123", ts: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated add reaction action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              timestamp: "1700000000.000100",
              name: "thumbsup"
            }} =
             Jido.Connect.Slack.Actions.AddReaction.run(
               %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated remove reaction action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              timestamp: "1700000000.000100",
              name: "thumbsup"
            }} =
             Jido.Connect.Slack.Actions.RemoveReaction.run(
               %{channel: "C123", timestamp: "1700000000.000100", name: "thumbsup"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated list reactions action delegates message and file targets through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              type: "message",
              channel: "C123",
              timestamp: "1700000000.000100",
              message: %{"text" => "Hello"},
              reactions: [%{"name" => "thumbsup", "count" => 1, "users" => ["U123"]}]
            }} =
             Jido.Connect.Slack.Actions.ListReactions.run(
               %{channel: "C123", timestamp: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:ok,
            %{
              type: "file",
              file_id: "F123",
              file: %{"name" => "report.txt"},
              reactions: [%{"name" => "eyes", "count" => 2, "users" => ["U123", "U456"]}]
            }} =
             Jido.Connect.Slack.Actions.ListReactions.run(
               %{file: "F123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated add pin action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              type: "message",
              channel: "C123",
              timestamp: "1700000000.000100"
            }} =
             Jido.Connect.Slack.Actions.AddPin.run(
               %{channel: "C123", timestamp: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated list pins action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: "C123",
              items: [
                %{
                  type: "message",
                  channel: "C123",
                  timestamp: "1700000000.000100",
                  created: 1_700_000_001,
                  created_by: "U123",
                  message: %{"text" => "Pinned"}
                },
                %{
                  type: "file",
                  created: 1_700_000_002,
                  created_by: "U456",
                  file: %{"id" => "F123"}
                }
              ]
            }} =
             Jido.Connect.Slack.Actions.ListPins.run(
               %{channel: "C123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated remove pin action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              type: "message",
              channel: "C123",
              timestamp: "1700000000.000100"
            }} =
             Jido.Connect.Slack.Actions.RemovePin.run(
               %{channel: "C123", timestamp: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated upload file action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              file_id: "F123",
              files: [%{"id" => "F123", "title" => "Report"}]
            }} =
             Jido.Connect.Slack.Actions.UploadFile.run(
               %{
                 channel_id: "C123",
                 filename: "report.txt",
                 content: "Hello file",
                 title: "Report",
                 initial_comment: "Here is the report"
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated share file action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              file_id: "F123",
              files: [%{"id" => "F123", "title" => "Report"}]
            }} =
             Jido.Connect.Slack.Actions.ShareFile.run(
               %{
                 file_id: "F123",
                 channels: "C123,C456",
                 title: "Report",
                 initial_comment: "Here is the report"
               },
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated delete file action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{file_id: "F123"}} =
             Jido.Connect.Slack.Actions.DeleteFile.run(
               %{file_id: "F123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated add reaction action validates channel timestamp and name" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "general",
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.AddReaction.run(
               %{channel: "general", timestamp: "1700000000.000100", name: "thumbsup"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "1700000000",
              details: %{field: :timestamp}
            }} =
             Jido.Connect.Slack.Actions.AddReaction.run(
               %{channel: "C123", timestamp: "1700000000", name: "thumbsup"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: ":thumbsup:",
              details: %{field: :name}
            }} =
             Jido.Connect.Slack.Actions.AddReaction.run(
               %{channel: "C123", timestamp: "1700000000.000100", name: ":thumbsup:"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated remove reaction action validates channel timestamp and name" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "general",
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.RemoveReaction.run(
               %{channel: "general", timestamp: "1700000000.000100", name: "thumbsup"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "1700000000",
              details: %{field: :timestamp}
            }} =
             Jido.Connect.Slack.Actions.RemoveReaction.run(
               %{channel: "C123", timestamp: "1700000000", name: "thumbsup"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: ":thumbsup:",
              details: %{field: :name}
            }} =
             Jido.Connect.Slack.Actions.RemoveReaction.run(
               %{channel: "C123", timestamp: "1700000000.000100", name: ":thumbsup:"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated list reactions action validates target shape" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :target}
            }} =
             Jido.Connect.Slack.Actions.ListReactions.run(
               %{},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "1700000000",
              details: %{field: :timestamp}
            }} =
             Jido.Connect.Slack.Actions.ListReactions.run(
               %{channel: "C123", timestamp: "1700000000"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              details: %{field: :target}
            }} =
             Jido.Connect.Slack.Actions.ListReactions.run(
               %{channel: "C123", timestamp: "1700000000.000100", file: "F123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated add pin action validates message item shape" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "general",
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.AddPin.run(
               %{channel: "general", timestamp: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "1700000000",
              details: %{field: :timestamp}
            }} =
             Jido.Connect.Slack.Actions.AddPin.run(
               %{channel: "C123", timestamp: "1700000000"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated list pins action validates channel shape" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "general",
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.ListPins.run(
               %{channel: "general"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated remove pin action validates message item shape" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "general",
              details: %{field: :channel}
            }} =
             Jido.Connect.Slack.Actions.RemovePin.run(
               %{channel: "general", timestamp: "1700000000.000100"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_input,
              subject: "1700000000",
              details: %{field: :timestamp}
            }} =
             Jido.Connect.Slack.Actions.RemovePin.run(
               %{channel: "C123", timestamp: "1700000000"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated auth test action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              team_id: "T123",
              team: "Demo",
              user_id: "U123",
              user: "demo-user",
              bot_id: "B123",
              enterprise_id: "E123",
              is_enterprise_install: true
            }} =
             Jido.Connect.Slack.Actions.AuthTest.run(
               %{},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated list users action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              users: [
                %{
                  id: "U123",
                  team_id: "T123",
                  name: "ada",
                  real_name: "Ada Lovelace",
                  profile: %{"email" => "ada@example.com"}
                }
              ],
              next_cursor: "next"
            }} =
             Jido.Connect.Slack.Actions.ListUsers.run(
               %{limit: 100},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated user info action distinguishes user and bot profiles" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              user_id: "U123",
              team_id: "T123",
              name: "ada",
              real_name: "Ada Lovelace",
              is_bot: false,
              is_app_user: false,
              user_type: "user",
              profile: %{
                email: "ada@example.com",
                display_name: "ada",
                real_name: "Ada Lovelace"
              },
              user: %{id: "U123"}
            }} =
             Jido.Connect.Slack.Actions.UserInfo.run(
               %{user: "U123"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:ok,
            %{
              user_id: "B123",
              name: "build-bot",
              is_bot: true,
              user_type: "bot",
              bot_id: "B999",
              profile: %{bot_id: "B999", display_name: "build-bot"}
            }} =
             Jido.Connect.Slack.Actions.UserInfo.run(
               %{user: "B123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated lookup user by email action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              user_id: "U123",
              team_id: "T123",
              name: "ada",
              real_name: "Ada Lovelace",
              user_type: "user",
              profile: %{
                email: "ada@example.com",
                display_name: "ada",
                real_name: "Ada Lovelace"
              },
              user: %{id: "U123"}
            }} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "ada@example.com"},
               %{integration_context: context, credential_lease: lease}
             )

    assert {:ok, %{user_id: "UAPP", user_type: "app_user"} = app_user} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "app@example.com"},
               %{integration_context: context, credential_lease: lease}
             )

    refute Map.has_key?(app_user, :profile)

    assert {:ok, %{user_id: "B123", user_type: "bot"} = bot_user} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "bot@example.com"},
               %{integration_context: context, credential_lease: lease}
             )

    refute Map.has_key?(bot_user, :profile)
  end

  test "lookup user by email returns config errors from missing client" do
    {context, lease} = context_and_lease()

    lease = %{lease | fields: %{access_token: "token"}}

    assert {:error,
            %Connect.Error.ConfigError{
              key: :slack_client,
              message: "Slack client module is required"
            }} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "ada@example.com"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "lookup user by email requires Slack email scope" do
    {context, lease} = context_and_lease()

    context = %{
      context
      | connection: %{
          context.connection
          | scopes: ["channels:read", "chat:write", "team:read", "users:read"]
        }
    }

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["users:read.email"]
            }} =
             Jido.Connect.Slack.Actions.LookupUserByEmail.run(
               %{email: "ada@example.com"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated team info action delegates through integration runtime" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              team_id: "T123",
              name: "Demo",
              domain: "demo",
              email_domain: "demo.example",
              enterprise_id: "E123",
              enterprise_name: "Example Enterprise",
              team: %{"id" => "T123"}
            }} =
             Jido.Connect.Slack.Actions.TeamInfo.run(
               %{team_id: "T123"},
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "generated plugin filters actions and reports availability" do
    spec = Jido.Connect.Slack.Plugin.plugin_spec(%{})

    assert spec.actions == [
             Jido.Connect.Slack.Actions.ListChannels,
             Jido.Connect.Slack.Actions.GetThreadReplies,
             Jido.Connect.Slack.Actions.GetConversationInfo,
             Jido.Connect.Slack.Actions.CreateChannel,
             Jido.Connect.Slack.Actions.ArchiveChannel,
             Jido.Connect.Slack.Actions.UnarchiveChannel,
             Jido.Connect.Slack.Actions.RenameChannel,
             Jido.Connect.Slack.Actions.InviteUsers,
             Jido.Connect.Slack.Actions.KickUser,
             Jido.Connect.Slack.Actions.OpenConversation,
             Jido.Connect.Slack.Actions.ListConversationMembers,
             Jido.Connect.Slack.Actions.SearchFiles,
             Jido.Connect.Slack.Actions.UploadFile,
             Jido.Connect.Slack.Actions.ShareFile,
             Jido.Connect.Slack.Actions.DeleteFile,
             Jido.Connect.Slack.Actions.AuthTest,
             Jido.Connect.Slack.Actions.TeamInfo,
             Jido.Connect.Slack.Actions.PostMessage,
             Jido.Connect.Slack.Actions.SearchMessages,
             Jido.Connect.Slack.Actions.PostEphemeral,
             Jido.Connect.Slack.Actions.ScheduleMessage,
             Jido.Connect.Slack.Actions.UnscheduleMessage,
             Jido.Connect.Slack.Actions.UpdateMessage,
             Jido.Connect.Slack.Actions.DeleteMessage,
             Jido.Connect.Slack.Actions.ListPins,
             Jido.Connect.Slack.Actions.AddPin,
             Jido.Connect.Slack.Actions.RemovePin,
             Jido.Connect.Slack.Actions.GetPresence,
             Jido.Connect.Slack.Actions.SetPresence,
             Jido.Connect.Slack.Actions.SetStatus,
             Jido.Connect.Slack.Actions.ClearStatus,
             Jido.Connect.Slack.Actions.ListEmoji,
             Jido.Connect.Slack.Actions.ListUnreadMessages,
             Jido.Connect.Slack.Actions.MarkConversationRead,
             Jido.Connect.Slack.Actions.ListReactions,
             Jido.Connect.Slack.Actions.AddReaction,
             Jido.Connect.Slack.Actions.RemoveReaction,
             Jido.Connect.Slack.Actions.ListUsers,
             Jido.Connect.Slack.Actions.UserInfo,
             Jido.Connect.Slack.Actions.LookupUserByEmail
           ]

    filtered =
      Jido.Connect.Slack.Plugin.plugin_spec(%{
        allowed_actions: ["slack.channel.list"]
      })

    assert filtered.actions == [Jido.Connect.Slack.Actions.ListChannels]

    [list_available | _] =
      Jido.Connect.Slack.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    assert list_available.state == :available

    [missing_scopes | _] =
      Jido.Connect.Slack.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["channels:read"]
  end

  test "generated app mention sensor exposes trigger metadata and metadata-only runtime mode" do
    assert_metadata_only_sensor(Jido.Connect.Slack.Sensors.AppMention, "slack.event.app_mention")
  end

  test "generated private channel message sensor exposes metadata-only runtime mode" do
    assert_metadata_only_sensor(
      Jido.Connect.Slack.Sensors.PrivateChannelMessage,
      "slack.event.message.groups"
    )
  end

  test "generated direct message sensor exposes metadata-only runtime mode" do
    assert_metadata_only_sensor(
      Jido.Connect.Slack.Sensors.DirectMessage,
      "slack.event.message.im"
    )
  end

  test "generated multi-person direct message sensor exposes metadata-only runtime mode" do
    assert_metadata_only_sensor(
      Jido.Connect.Slack.Sensors.MultiPersonDirectMessage,
      "slack.event.message.mpim"
    )
  end

  test "generated thread reply sensor exposes metadata-only runtime mode" do
    assert_metadata_only_sensor(
      Jido.Connect.Slack.Sensors.ThreadReply,
      "slack.event.message.thread_reply"
    )
  end

  test "generated reaction added sensor exposes metadata-only runtime mode" do
    assert_metadata_only_sensor(
      Jido.Connect.Slack.Sensors.ReactionAdded,
      "slack.event.reaction_added"
    )
  end

  test "generated reaction removed sensor exposes metadata-only runtime mode" do
    assert_metadata_only_sensor(
      Jido.Connect.Slack.Sensors.ReactionRemoved,
      "slack.event.reaction_removed"
    )
  end

  test "generated channel lifecycle sensors expose metadata-only runtime mode" do
    sensors = [
      {Jido.Connect.Slack.Sensors.ChannelCreated, "slack.event.channel_created"},
      {Jido.Connect.Slack.Sensors.ChannelRename, "slack.event.channel_rename"},
      {Jido.Connect.Slack.Sensors.ChannelArchive, "slack.event.channel_archive"},
      {Jido.Connect.Slack.Sensors.ChannelUnarchive, "slack.event.channel_unarchive"},
      {Jido.Connect.Slack.Sensors.MemberJoinedChannel, "slack.event.member_joined_channel"},
      {Jido.Connect.Slack.Sensors.MemberLeftChannel, "slack.event.member_left_channel"},
      {Jido.Connect.Slack.Sensors.AppUninstalled, "slack.event.app_uninstalled"},
      {Jido.Connect.Slack.Sensors.TokensRevoked, "slack.event.tokens_revoked"},
      {Jido.Connect.Slack.Sensors.ScopeDenied, "slack.event.scope_denied"},
      {Jido.Connect.Slack.Sensors.AppHomeOpened, "slack.event.app_home_opened"}
    ]

    for {sensor, trigger_id} <- sensors do
      assert_metadata_only_sensor(sensor, trigger_id)
    end
  end

  defp assert_metadata_only_sensor(sensor, trigger_id) do
    assert sensor.trigger_id() == trigger_id
    assert sensor.signal_type() == trigger_id
    assert sensor.signal_source() == "/jido/connect/slack"
    assert sensor.runtime_mode() == :metadata_only

    assert %{runtime_mode: :metadata_only} = sensor.jido_connect_projection()
    assert {:ok, state} = sensor.init(%{}, %{})

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :webhook_runtime,
              details: %{
                trigger_id: ^trigger_id,
                runtime_mode: :metadata_only
              }
            }} = sensor.handle_event(:anything, state)
  end

  defp context_and_lease(opts \\ []) do
    profile = Keyword.get(opts, :profile, :bot)
    access_token = Keyword.get(opts, :access_token, "token")

    connection =
      Connect.Connection.new!(%{
        id: "slack-team-T123",
        provider: :slack,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: if(profile == :user, do: :user, else: :tenant),
        owner_id: if(profile == :user, do: "user_1", else: "T123"),
        status: :connected,
        scopes: [
          "channels:read",
          "channels:manage",
          "channels:history",
          "groups:write",
          "im:write",
          "mpim:write",
          "chat:write",
          "files:write",
          "pins:read",
          "pins:write",
          "reactions:read",
          "reactions:write",
          "search:read",
          "team:read",
          "users:read",
          "users:read.email"
        ]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "slack-team-T123",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token, slack_client: FakeSlackClient}
      })

    {context, lease}
  end
end
