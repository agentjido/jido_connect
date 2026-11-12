defmodule Jido.Connect.Slack.Client.ConversationsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.{Client, Message}
  alias Jido.Connect.TestSupport.LiveSmoke

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

    Application.put_env(:jido_connect_slack, :slack_upload_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_req_options)
      Application.delete_env(:jido_connect_slack, :slack_upload_req_options)
    end)
  end

  test "list channels sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.list"

      assert %{
               "exclude_archived" => "true",
               "limit" => "100",
               "types" => "public_channel"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        channels: [
          %{
            id: "C123",
            name: "general",
            is_archived: false,
            is_private: false,
            is_member: true
          }
        ],
        response_metadata: %{next_cursor: "next"}
      })
    end)

    assert {:ok, %{channels: [%{id: "C123", name: "general"}], next_cursor: "next"}} =
             Client.list_channels(
               %{types: "public_channel", exclude_archived: true, limit: 100},
               "token"
             )
  end

  test "list conversation members sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.members"

      assert %{
               "channel" => "C123",
               "cursor" => "page-1",
               "limit" => "100"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        members: ["U123", "U456"],
        response_metadata: %{next_cursor: "page-2"}
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              members: ["U123", "U456"],
              next_cursor: "page-2"
            }} =
             Client.list_conversation_members(
               %{channel: "C123", limit: 100, cursor: "page-1"},
               "token"
             )
  end

  test "get conversation info sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.info"

      assert %{
               "channel" => "C123",
               "include_locale" => "true"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "C123",
          name: "general",
          is_channel: true,
          is_private: false
        }
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              conversation: %{
                "id" => "C123",
                "name" => "general",
                "is_channel" => true
              }
            }} =
             Client.get_conversation_info(
               %{channel: "C123", include_locale: true},
               "token"
             )
  end

  test "create channel sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.create"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "name" => "project-updates",
               "is_private" => true,
               "team_id" => "T123"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "G123",
          name: "project-updates",
          is_archived: false,
          is_private: true,
          is_member: true,
          purpose: %{value: "raw value"}
        }
      })
    end)

    assert {:ok,
            %{
              channel: %{
                id: "G123",
                name: "project-updates",
                is_archived: false,
                is_private: true,
                is_member: true
              }
            }} =
             Client.create_channel(
               %{name: "project-updates", is_private: true, team_id: "T123"},
               "token"
             )
  end

  test "archive conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.archive"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123"} = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123"}} =
             Client.archive_conversation(%{channel: "C123"}, "token")
  end

  test "unarchive conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.unarchive"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123"} = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123"}} =
             Client.unarchive_conversation(%{channel: "C123"}, "token")
  end

  test "unarchive conversation normalizes Slack errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.unarchive"

      Req.Test.json(conn, %{ok: false, error: "not_archived"})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: "not_archived"
            }} =
             Client.unarchive_conversation(%{channel: "C123"}, "token")
  end

  test "rename conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.rename"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "name" => "renamed-channel"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "C123",
          name: "renamed-channel",
          is_archived: false,
          is_private: false,
          is_member: true,
          purpose: %{value: "raw value"}
        }
      })
    end)

    assert {:ok,
            %{
              channel: %{
                id: "C123",
                name: "renamed-channel",
                is_archived: false,
                is_private: false,
                is_member: true
              }
            }} =
             Client.rename_conversation(%{channel: "C123", name: "renamed-channel"}, "token")
  end

  test "invite conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.invite"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "users" => "U123,U456", "force" => true} =
               Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: %{
          id: "C123",
          name: "project-updates",
          is_archived: false,
          is_private: false,
          is_member: true
        }
      })
    end)

    assert {:ok,
            %{
              channel: %{
                id: "C123",
                name: "project-updates",
                is_archived: false,
                is_private: false,
                is_member: true
              },
              invited_users: ["U123", "U456"],
              failed_users: [],
              partial_failure: false
            }} =
             Client.invite_conversation(
               %{channel: "C123", users: ["U123", "U456"], force: true},
               "token"
             )
  end

  test "invite conversation normalizes partial failures when force is enabled" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.invite"

      Req.Test.json(conn, %{
        ok: false,
        error: "user_not_found",
        errors: [
          %{user: "U404", ok: false, error: "user_not_found"}
        ]
      })
    end)

    assert {:ok,
            %{
              channel: %{id: "C123"},
              invited_users: ["U123"],
              failed_users: [%{user: "U404", ok: false, error: "user_not_found"}],
              partial_failure: true
            }} =
             Client.invite_conversation(
               %{channel: "C123", users: ["U123", "U404"], force: true},
               "token"
             )
  end

  test "invite conversation returns provider error for partial failures without force" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.invite"

      Req.Test.json(conn, %{
        ok: false,
        error: "user_not_found",
        errors: [
          %{user: "U404", ok: false, error: "user_not_found"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              reason: "user_not_found",
              details: %{failed_users: [%{user: "U404", ok: false, error: "user_not_found"}]}
            }} =
             Client.invite_conversation(
               %{channel: "C123", users: ["U123", "U404"], force: false},
               "token"
             )
  end

  test "kick conversation sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.kick"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"channel" => "C123", "user" => "U123"} = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", user: "U123"}} =
             Client.kick_conversation(%{channel: "C123", user: "U123"}, "token")
  end

  # Recorded from the test workspace: the bot opens its group DM with the
  # authorizing and the second user.
  test "open conversation sends expected request and normalizes output" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.open"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "users" => "U0CDPFT1RDJ,U0CDEL6734M",
               "return_im" => false,
               "prevent_creation" => false
             }

      Req.Test.json(conn, LiveSmoke.fixture!(:slack, "conversations_open_mpim"))
    end)

    assert {:ok,
            %{
              channel: "C0CDELYPYKF",
              conversation: %{
                id: "C0CDELYPYKF",
                name: "name-1",
                is_im: false,
                is_mpim: true,
                is_private: true,
                is_open: true
              }
            }} ==
             Client.open_conversation(
               %{
                 users: ["U0CDPFT1RDJ", "U0CDEL6734M"],
                 return_im: false,
                 prevent_creation: false
               },
               "token"
             )
  end

  # Recorded from the test workspace: the bot opens its DM with the
  # authorizing user and asks for the full DM definition.
  test "open conversation sends return_im and returns the DM's user" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/api/conversations.open"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "users" => "U0CDPFT1RDJ",
               "return_im" => true,
               "prevent_creation" => false
             }

      Req.Test.json(conn, LiveSmoke.fixture!(:slack, "conversations_open_im_return_im"))
    end)

    assert {:ok,
            %{
              channel: "D0CD4G48UFR",
              conversation: %{
                id: "D0CD4G48UFR",
                is_im: true,
                is_open: true,
                user: "U0CDPFT1RDJ"
              }
            }} ==
             Client.open_conversation(
               %{users: ["U0CDPFT1RDJ"], return_im: true, prevent_creation: false},
               "token"
             )
  end

  describe "get_conversation_history/2" do
    # Recorded from the public channel of the test workspace with the bot token.
    @channel "C0CEEB41FU0"
    @bot_user "U0CDHUEBVEJ"
    @bot_id "B0CDHUEB8MC"
    @app_id "A0CDHUBBHRC"
    @authorizing_user "U0CDPFT1RDJ"
    @second_user "U0CDEL6734M"

    test "sends a bearer GET with exactly the allowlisted parameters" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/conversations.history"
        assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

        assert URI.decode_query(conn.query_string) == %{
                 "channel" => @channel,
                 "cursor" => "page-2",
                 "oldest" => "1793371017.000000",
                 "latest" => "1793373462.345279",
                 "inclusive" => "true",
                 "limit" => "7"
               }

        Req.Test.json(conn, LiveSmoke.fixture!(:slack, "conversation_history_pages"))
      end)

      assert {:ok, %{messages: [_ | _]}} =
               Client.get_conversation_history(
                 %{
                   channel: @channel,
                   conversation_type: "public_channel",
                   cursor: "page-2",
                   oldest: "1793371017.000000",
                   latest: "1793373462.345279",
                   inclusive: true,
                   limit: 7,
                   include_all_metadata: true
                 },
                 "token"
               )
    end

    test "a full page keeps the cursor and has_more with one request" do
      body = LiveSmoke.fixture!(:slack, "conversation_history_pages")
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

      assert {:ok, page} = Client.get_conversation_history(params(limit: 7), "token")

      assert page.next_cursor == body["response_metadata"]["next_cursor"]
      assert page.next_cursor != ""
      assert page.has_more == true
      refute Map.has_key?(page, :is_limited)
      assert length(page.messages) == 7
      assert Enum.map(page.messages, & &1.ts) == Enum.map(body["messages"], & &1["ts"])

      assert Enum.all?(page.messages, fn message ->
               match?(%Message{channel: @channel, conversation_type: "public_channel"}, message)
             end)
    end

    test "a short last page and an empty page keep their flags without another request" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case URI.decode_query(conn.query_string) do
          %{"cursor" => "page-2"} ->
            Req.Test.json(conn, LiveSmoke.fixture!(:slack, "conversation_history_pages.2"))

          %{"latest" => "1000000000.000000"} ->
            Req.Test.json(conn, LiveSmoke.fixture!(:slack, "conversation_history_empty"))
        end
      end)

      assert {:ok, %{next_cursor: "", has_more: false, messages: short} = page} =
               Client.get_conversation_history(params(limit: 7, cursor: "page-2"), "token")

      assert length(short) == 5
      refute Map.has_key?(page, :is_limited)

      assert {:ok, %{messages: [], next_cursor: "", has_more: false}} =
               Client.get_conversation_history(params(latest: "1000000000.000000"), "token")
    end

    test "is_limited passes through when Slack sends it" do
      # Slack did not send is_limited for the test workspace; this adds it to
      # the recorded empty page.
      body =
        :slack
        |> LiveSmoke.fixture!("conversation_history_empty")
        |> Map.put("is_limited", true)

      Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

      assert {:ok, %{messages: [], is_limited: true, has_more: false}} =
               Client.get_conversation_history(params(), "token")
    end

    test "a page without messages or with a wrongly typed flag or cursor fails" do
      body = LiveSmoke.fixture!(:slack, "conversation_history_pages")

      # A missing messages list must not read as an empty last page.
      for broken <- [
            Map.delete(body, "messages"),
            Map.put(body, "has_more", "true"),
            put_in(body, ["response_metadata", "next_cursor"], 42),
            Map.put(body, "is_limited", "true")
          ] do
        Req.Test.expect(__MODULE__, &Req.Test.json(&1, broken))

        assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_response}} =
                 Client.get_conversation_history(params(), "token")
      end
    end

    test "human, bot and file messages keep content and source identity" do
      body = LiveSmoke.fixture!(:slack, "conversation_history_pages")
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

      assert {:ok, %{messages: messages}} = Client.get_conversation_history(params(), "token")
      raw = Map.new(body["messages"], &{&1["ts"], &1})
      by_ts = Map.new(messages, &{&1.ts, &1})

      human = by_ts["1793373170.496259"]
      assert human.user == @second_user
      assert human.bot_id == nil
      assert human.app_id == nil
      assert human.subtype == nil
      assert human.text == raw[human.ts]["text"]
      assert human.blocks == raw[human.ts]["blocks"]

      bot = by_ts["1793373462.345279"]
      assert {bot.user, bot.bot_id, bot.app_id} == {@bot_user, @bot_id, @app_id}

      # Slack sends no file_share subtype in conversations.history: a file
      # share is a message with files, from a person or from the bot.
      human_upload = by_ts["1793373047.341389"]
      assert human_upload.user == @authorizing_user
      assert human_upload.subtype == nil
      assert human_upload.files == raw[human_upload.ts]["files"]
      assert human_upload.edited == %{user: @authorizing_user, ts: "1793373063.000000"}

      bot_upload = by_ts["1793371033.743069"]
      assert {bot_upload.bot_id, bot_upload.subtype} == {@bot_id, nil}
      assert [%{"id" => "F0CD4JHBJ8P"}] = bot_upload.files

      assert by_ts["1793371031.138169"].edited == %{
               user: @bot_user,
               ts: "1793371032.000000"
             }

      thread_root = by_ts["1793371034.447499"]
      assert thread_root.thread_ts == "1793371034.447499"
      assert human.thread_ts == nil
      assert human.edited == nil
    end

    test "text over 512 bytes, subtypes and absent blocks pass through unchanged" do
      body = LiveSmoke.fixture!(:slack, "conversation_history_pages.2")
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

      assert {:ok, %{messages: messages}} = Client.get_conversation_history(params(), "token")
      [long | _rest] = messages
      [raw_long | _raw_rest] = body["messages"]

      assert long.ts == "1793371020.846869"
      assert byte_size(long.text) == 1293
      assert long.text == raw_long["text"]
      assert long.blocks == raw_long["blocks"]

      joins = Enum.filter(messages, &(&1.subtype == "channel_join"))
      assert length(joins) == 3
      assert Enum.all?(joins, &(&1.blocks == nil and &1.bot_id == nil))
    end

    test "attachments and an empty text stay as Slack sends them" do
      body = LiveSmoke.fixture!(:slack, "conversation_history_attachments")
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

      assert {:ok, %{messages: [message], has_more: false}} =
               Client.get_conversation_history(params(), "token")

      [raw] = body["messages"]
      assert message.text == ""
      assert message.attachments == raw["attachments"]
      assert message.blocks == nil
      assert message.files == nil
      assert {message.user, message.bot_id, message.app_id} == {@bot_user, @bot_id, @app_id}
    end

    test "a malformed message record fails instead of disappearing" do
      body = LiveSmoke.fixture!(:slack, "conversation_history_pages")
      [first | rest] = body["messages"]

      for broken <- [
            Map.delete(first, "ts"),
            Map.put(first, "ts", 1_793_373_462.345279),
            Map.put(first, "thread_ts", 1_793_373_462.345279),
            Map.put(first, "user", %{"id" => @bot_user}),
            Map.put(first, "bot_id", 42),
            Map.put(first, "app_id", 42),
            Map.put(first, "text", 42),
            Map.put(first, "blocks", "not a list"),
            Map.put(first, "attachments", %{"title" => "not a list"}),
            Map.put(first, "files", ["not a map"]),
            Map.put(first, "subtype", 42),
            Map.put(first, "edited", %{"user" => @bot_user}),
            "not a message"
          ] do
        Req.Test.expect(__MODULE__, &Req.Test.json(&1, %{body | "messages" => [broken | rest]}))

        assert {:error, %Error.ProviderError{provider: :slack, reason: :invalid_response}} =
                 Client.get_conversation_history(params(), "token")
      end
    end

    test "a denied read returns the Slack error without the response body" do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.json(conn, LiveSmoke.fixture!(:slack, "conversation_history_not_in_channel"))
      end)

      assert {:error,
              %Error.ProviderError{
                provider: :slack,
                status: 200,
                reason: "not_in_channel",
                details: details
              }} =
               Client.get_conversation_history(params(channel: "C0CDDP1JEAX"), "token")

      refute Map.has_key?(details, :body)
    end

    test "a missing channel or an unknown conversation type fails before any request" do
      Req.Test.stub(__MODULE__, fn _conn -> flunk("no request expected") end)

      for params <- [
            Map.delete(params(), :channel),
            params(channel: ""),
            Map.delete(params(), :conversation_type),
            params(conversation_type: "group")
          ] do
        assert {:error, %Error.ValidationError{}} =
                 Client.get_conversation_history(params, "token")
      end
    end

    test "string keys fail validation like missing ones, since only atom keys are sent" do
      Req.Test.stub(__MODULE__, fn _conn -> flunk("no request expected") end)

      assert {:error, %Error.ValidationError{reason: :missing_channel}} =
               Client.get_conversation_history(
                 %{"channel" => @channel, "conversation_type" => "im"},
                 "token"
               )

      assert {:error, %Error.ValidationError{reason: :invalid_conversation_type}} =
               Client.get_conversation_history(
                 %{:channel => @channel, "conversation_type" => "im"},
                 "token"
               )
    end

    defp params(overrides \\ []) do
      Enum.into(overrides, %{channel: @channel, conversation_type: "public_channel"})
    end
  end
end
