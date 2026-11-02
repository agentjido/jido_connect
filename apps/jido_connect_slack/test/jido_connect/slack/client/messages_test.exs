defmodule Jido.Connect.Slack.Client.MessagesTest do
  use ExUnit.Case, async: false
  alias Jido.Connect
  alias Jido.Connect.Slack.Client
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

  # The thread recordings come from the test workspace: the prepared thread
  # with 22 replies in the public channel, its oldest and fourth oldest
  # reply, a parent without replies, and the authors' IDs.
  @channel "C0CEEB41FU0"
  @private_channel "C0CD4JEJ9V5"
  @parent "1793371034.447499"
  @window_oldest "1793371035.936349"
  @window_latest "1793371040.433599"
  @long_reply "1793371049.278489"
  @lone_parent "1793371020.846869"
  @unknown_ts "1000000000.000100"
  @authorizing_user "U0CDPFT1RDJ"
  @bot_user "U0CDHUEBVEJ"
  @bot_id "B0CDHUEB8MC"
  @app_id "A0CDHUBBHRC"

  # Recorded: the second page of a read of the prepared thread with limit 2,
  # inclusive, from its oldest to its fourth oldest reply, requested with the
  # cursor of the first page.
  test "get thread replies sends the time window, the cursor and the page size" do
    cursor = next_cursor!("thread_replies_window")
    %{"messages" => messages} = page = LiveSmoke.fixture!(:slack, "thread_replies_window.2")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.replies"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      assert URI.decode_query(conn.query_string) == %{
               "channel" => @channel,
               "ts" => @parent,
               "cursor" => cursor,
               "limit" => "2",
               "inclusive" => "true",
               "oldest" => @window_oldest,
               "latest" => @window_latest
             }

      Req.Test.json(conn, page)
    end)

    assert Client.get_thread_replies(
             %{
               channel: @channel,
               ts: @parent,
               cursor: cursor,
               limit: 2,
               inclusive: true,
               oldest: @window_oldest,
               latest: @window_latest
             },
             "token"
           ) ==
             {:ok,
              %{
                channel: @channel,
                thread_ts: @parent,
                messages: messages,
                next_cursor: "",
                has_more: false
              }}
  end

  # Recorded: Slack answers an unknown parent ts with HTTP 200 and ok: false.
  # The client and the action both return it as an error.
  test "get thread replies returns an unknown thread as a provider error, not as an empty page" do
    not_found = LiveSmoke.fixture!(:slack, "thread_replies_thread_not_found")
    expect_pages([not_found, not_found])

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: "thread_not_found"
            }} = Client.get_thread_replies(%{channel: @channel, ts: @unknown_ts}, "token")

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: "thread_not_found"
            }} =
             invoke(%{channel: @channel, ts: @unknown_ts, conversation_type: "public_channel"})
  end

  describe "slack.thread.replies through Jido.Connect.invoke" do
    # Recorded: a parent without replies in the private channel, read with
    # groups:history.
    test "a private channel read sends only channel, ts, limit and inclusive" do
      %{"messages" => [%{"ts" => ts}]} =
        page = LiveSmoke.fixture!(:slack, "thread_replies_private_no_replies")

      expect_pages([page])

      assert {:ok, %{messages: [%{ts: ^ts}]}} =
               invoke(
                 %{channel: @private_channel, ts: ts, conversation_type: "private_channel"},
                 ["groups:history"]
               )

      assert_received {:slack_request, query}

      assert query == %{
               "channel" => @private_channel,
               "ts" => ts,
               "limit" => "100",
               "inclusive" => "false"
             }
    end

    # Recorded: the prepared thread from its reply over 512 bytes to the
    # newest reply. For the recording the live test added two bot replies,
    # one with a file and one with a legacy attachment and a reaction, and
    # deleted them afterwards.
    test "a page keeps authors, the long text, files, reactions, blocks and attachments as recorded" do
      %{"messages" => recorded} =
        page = LiveSmoke.fixture!(:slack, "thread_replies_message_kinds")

      expect_pages([page])

      assert {:ok, %{has_more: false, messages: messages} = result} =
               invoke(%{
                 channel: @channel,
                 ts: @parent,
                 conversation_type: "public_channel",
                 oldest: @long_reply,
                 inclusive: true
               })

      assert_received {:slack_request,
                       %{"oldest" => @long_reply, "inclusive" => "true", "limit" => "100"}}

      refute Map.has_key?(result, :next_cursor)
      assert length(messages) == length(recorded)

      for {message, raw} <- Enum.zip(messages, recorded),
          field <- [:ts, :thread_ts, :files, :reactions, :blocks, :attachments] do
        assert Map.get(message, field) == raw[Atom.to_string(field)],
               "#{field} of #{raw["ts"]} differs from the recording"
      end

      by_ts = Map.new(messages, &{&1.ts, &1})

      assert %{user: @authorizing_user} = human = by_ts["1793373003.591279"]
      refute Map.has_key?(human, :bot_id)
      refute Map.has_key?(human, :app_id)

      assert %{user: @bot_user, bot_id: @bot_id, app_id: @app_id} = by_ts["1793371050.775499"]

      assert %{"text" => long_text} = Enum.find(recorded, &(&1["ts"] == @long_reply))
      assert byte_size(long_text) > 512
      assert by_ts[@long_reply].text === long_text

      assert [%{files: [%{"id" => "F" <> _id}]}] =
               Enum.filter(messages, &Map.has_key?(&1, :files))

      assert [%{reactions: [%{"name" => "white_check_mark", "count" => 1}], attachments: [_]}] =
               Enum.filter(messages, &Map.has_key?(&1, :reactions))
    end

    # Recorded: both pages of a read with limit 2, inclusive, from the
    # thread's oldest to its fourth oldest reply. Slack puts the parent first
    # on each page and the newer replies on the first page.
    test "two pages of limit 2 hand on the cursor, and page one reports the parent's summary" do
      first_page = LiveSmoke.fixture!(:slack, "thread_replies_window")
      cursor = next_cursor!("thread_replies_window")
      expect_pages([first_page, LiveSmoke.fixture!(:slack, "thread_replies_window.2")])

      input = %{
        channel: @channel,
        ts: @parent,
        conversation_type: "public_channel",
        limit: 2,
        oldest: @window_oldest,
        latest: @window_latest,
        inclusive: true
      }

      assert {:ok, %{has_more: true, next_cursor: ^cursor} = first} = invoke(input)
      assert {:ok, %{has_more: false} = second} = invoke(Map.put(input, :cursor, cursor))
      refute Map.has_key?(second, :next_cursor)

      window_query = %{
        "channel" => @channel,
        "ts" => @parent,
        "limit" => "2",
        "inclusive" => "true",
        "oldest" => @window_oldest,
        "latest" => @window_latest
      }

      assert_received {:slack_request, ^window_query}
      assert_received {:slack_request, second_query}
      assert second_query == Map.put(window_query, "cursor", cursor)

      # Page one holds two of the thread's 22 replies; the parent's summary
      # names all 22 and the second user's reply as the latest.
      assert [%{ts: @parent}, %{ts: "1793371038.970209"}, %{ts: @window_latest}] =
               first.messages

      assert %{"messages" => [%{"reply_count" => 22, "latest_reply" => latest} | _]} = first_page
      assert latest == "1793373203.070489"
      assert {first.reply_count, first.latest_reply} == {22, latest}
      assert first.reply_count != length(first.messages) - 1
      assert first.latest_reply != List.last(first.messages).ts

      assert [%{ts: @parent}, %{ts: @window_oldest}, %{ts: "1793371037.472009"}] =
               second.messages
    end

    # Recorded: Slack answers a parent without replies with the parent alone.
    # Without a reply_count from Slack the summary is computed from the page,
    # whose last ts is the parent's own.
    test "a parent without replies returns its single message and reply_count 0" do
      expect_pages([LiveSmoke.fixture!(:slack, "thread_replies_no_replies")])

      assert {:ok,
              %{
                messages: [%{ts: @lone_parent}],
                reply_count: 0,
                latest_reply: @lone_parent,
                has_more: false
              }} =
               invoke(%{channel: @channel, ts: @lone_parent, conversation_type: "public_channel"})
    end
  end

  test "search messages sends expected request and normalizes pagination" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/search.messages"

      assert %{
               "query" => "deploy in:#general",
               "sort" => "timestamp",
               "sort_dir" => "desc",
               "count" => "10",
               "page" => "2",
               "highlight" => "true",
               "cursor" => "page-1"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
        query: "deploy in:#general",
        messages: %{
          matches: [
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
          pagination: %{page: 2, per_page: 10, total_count: 1},
          paging: %{page: 2, count: 10, total: 1},
          total: 1
        },
        response_metadata: %{next_cursor: "page-2"}
      })
    end)

    assert {:ok,
            %{
              query: "deploy in:#general",
              messages: [%{"text" => "deploy finished"}],
              total_count: 1,
              pagination: %{"page" => 2, "per_page" => 10, "total_count" => 1},
              paging: %{"page" => 2, "count" => 10, "total" => 1},
              next_cursor: "page-2"
            }} =
             Client.search_messages(
               %{
                 query: "deploy in:#general",
                 sort: "timestamp",
                 sort_dir: "desc",
                 count: 10,
                 page: 2,
                 highlight: true,
                 cursor: "page-1"
               },
               "token"
             )
  end

  # Recorded from the test workspace: the bot posts a text with a link,
  # longer than 512 bytes, to the public channel.
  test "post message sends expected request" do
    %{"ts" => ts, "message" => %{"text" => text} = message} =
      fixture = LiveSmoke.fixture!(:slack, "chat_post_message_channel")

    assert byte_size(text) > 512

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.postMessage"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"channel" => "C0CEEB41FU0", "text" => text}

      Req.Test.json(conn, fixture)
    end)

    assert {:ok, %{channel: "C0CEEB41FU0", ts: ts, message: message}} ==
             Client.post_message(%{channel: "C0CEEB41FU0", text: text}, "token")
  end

  test "schedule message sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.scheduleMessage"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "text" => "Later",
               "post_at" => 1_700_000_600
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        scheduled_message_id: "Q123",
        post_at: "1700000600",
        message: %{text: "Later", type: "delayed_message"}
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              scheduled_message_id: "Q123",
              post_at: 1_700_000_600,
              message: %{"text" => "Later", "type" => "delayed_message"}
            }} =
             Client.schedule_message(
               %{channel: "C123", text: "Later", post_at: 1_700_000_600},
               "token"
             )
  end

  test "delete scheduled message sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.deleteScheduledMessage"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "scheduled_message_id" => "Q123"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", scheduled_message_id: "Q123"}} =
             Client.delete_scheduled_message(
               %{channel: "C123", scheduled_message_id: "Q123"},
               "token"
             )
  end

  test "update message sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.update"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "ts" => "1700000000.000100",
               "text" => "Updated",
               "blocks" => [%{"type" => "section"}]
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        ts: "1700000000.000100",
        message: %{text: "Updated"}
      })
    end)

    assert {:ok, %{channel: "C123", ts: "1700000000.000100"}} =
             Client.update_message(
               %{
                 channel: "C123",
                 ts: "1700000000.000100",
                 text: "Updated",
                 blocks: [%{type: "section"}]
               },
               "token"
             )
  end

  test "delete message sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.delete"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "ts" => "1700000000.000100"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        channel: "C123",
        ts: "1700000000.000100"
      })
    end)

    assert {:ok, %{channel: "C123", ts: "1700000000.000100"}} =
             Client.delete_message(%{channel: "C123", ts: "1700000000.000100"}, "token")
  end

  defp next_cursor!(fixture) do
    assert %{"response_metadata" => %{"next_cursor" => cursor}} =
             LiveSmoke.fixture!(:slack, fixture)

    assert is_binary(cursor) and cursor != ""
    cursor
  end

  # Answers one conversations.replies request per page, in order, and sends
  # each request's query to the test.
  defp expect_pages(pages) do
    test_pid = self()

    for page <- pages do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/conversations.replies"
        assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")
        send(test_pid, {:slack_request, URI.decode_query(conn.query_string)})
        Req.Test.json(conn, page)
      end)
    end
  end

  # The lease carries no `slack_client`, so the action uses `Client` and the
  # stub above answers its request.
  defp invoke(input, scopes \\ ["channels:history"]) do
    connection =
      Connect.Connection.new!(%{
        id: "slack-bot",
        provider: :slack,
        profile: :bot,
        tenant_id: "tenant-1",
        owner_type: :tenant,
        owner_id: "owner-1",
        status: :connected,
        scopes: scopes
      })

    Connect.invoke(Jido.Connect.Slack, "slack.thread.replies", input,
      context:
        Connect.Context.new!(%{
          tenant_id: "tenant-1",
          actor: %{id: "user-1", type: :user},
          connection: connection
        }),
      credential_lease:
        Connect.CredentialLease.new!(%{
          connection_id: connection.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          scopes: scopes,
          fields: %{access_token: "token"}
        })
    )
  end
end
