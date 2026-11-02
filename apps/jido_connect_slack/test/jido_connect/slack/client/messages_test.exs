defmodule Jido.Connect.Slack.Client.MessagesTest do
  use ExUnit.Case, async: false
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

  test "get thread replies sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/conversations.replies"

      assert %{
               "channel" => "C123",
               "cursor" => "page-1",
               "inclusive" => "true",
               "limit" => "50",
               "ts" => "1700000000.000100"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        ok: true,
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
        has_more: true,
        response_metadata: %{next_cursor: "page-2"}
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              thread_ts: "1700000000.000100",
              messages: [%{"text" => "Root"}, %{"text" => "Reply"}],
              next_cursor: "page-2",
              has_more: true
            }} =
             Client.get_thread_replies(
               %{
                 channel: "C123",
                 ts: "1700000000.000100",
                 limit: 50,
                 cursor: "page-1",
                 inclusive: true
               },
               "token"
             )
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
end
