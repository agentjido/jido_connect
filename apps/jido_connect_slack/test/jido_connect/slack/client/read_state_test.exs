defmodule Jido.Connect.Slack.Client.ReadStateTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Client
  alias Jido.Connect.Slack.Client.Transport

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_req_options)
    end)
  end

  test "lists bounded unread messages with explicit coverage" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/api/users.conversations" ->
          assert conn.method == "GET"

          Req.Test.json(conn, %{
            ok: true,
            channels: [
              %{
                id: "C123",
                name: "general",
                is_channel: true,
                last_read: "1700000000.000100",
                unread_count_display: 2
              },
              %{id: "C456", name: "quiet", is_channel: true, unread_count_display: 0}
            ],
            response_metadata: %{next_cursor: ""}
          })

        "/api/conversations.history" ->
          assert conn.method == "GET"

          assert %{
                   "channel" => "C123",
                   "inclusive" => "false",
                   "limit" => "5",
                   "oldest" => "1700000000.000100"
                 } = URI.decode_query(conn.query_string)

          Req.Test.json(conn, %{
            ok: true,
            messages: [
              %{ts: "1700000002.000200", user: "U2", text: "Second"},
              %{ts: "1700000001.000100", user: "U1", text: "First"}
            ],
            has_more: false
          })
      end
    end)

    assert {:ok,
            %{
              count: 2,
              truncated: false,
              messages: [
                %{channel_id: "C123", text: "Second"},
                %{channel_id: "C123", text: "First"}
              ],
              conversations: [%{id: "C123", unread_count: 2}],
              coverage: %{
                complete: true,
                inspected_conversation_count: 2,
                supported_conversation_count: 2,
                unsupported_conversation_count: 0
              }
            }} = Client.list_unread_messages(%{limit: 5}, "token")
  end

  test "marks one exact conversation timestamp" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/conversations.mark"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"channel" => "C123", "ts" => "1700000001.000100"}
      Req.Test.json(conn, %{ok: true})
    end)

    assert {:ok, %{channel: "C123", ts: "1700000001.000100"}} =
             Client.mark_conversation_read(
               %{channel: "C123", ts: "1700000001.000100"},
               "token"
             )
  end

  test "rejects an invalid successful history response" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/api/conversations.info" ->
          Req.Test.json(conn, %{
            ok: true,
            channel: %{id: "C123", last_read: "1700000000.000100", unread_count: 1}
          })

        "/api/conversations.history" ->
          Req.Test.json(conn, %{ok: true, messages: [%{text: "missing timestamp"}]})
      end
    end)

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Client.list_unread_messages(%{channel: "C123", limit: 5}, "token")
  end

  test "Slack transport disables automatic retries for uncertain writes" do
    assert Transport.request("token").options.retry == false

    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :write_attempt)
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Error.ProviderError{reason: :request_error}} =
             Client.mark_conversation_read(
               %{channel: "C123", ts: "1700000001.000100"},
               "token"
             )

    assert_receive :write_attempt
    refute_receive :write_attempt, 50
  end
end
