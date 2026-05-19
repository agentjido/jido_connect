defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.ReplyMessageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.ReplyMessage

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_graph_base_url, "https://graph.test")

    Application.put_env(:jido_connect_microsoft, :microsoft_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      Application.delete_env(:jido_connect_microsoft, :microsoft_req_options)
    end)
  end

  describe "run/2" do
    test "replies to a message with a comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/messages/AAMkAGI2TG93AAAqBGHNAAA=/reply"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["comment"] == "Thanks for the update!"

        conn |> Plug.Conn.put_status(202) |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{sent: true, message_id: "AAMkAGI2TG93AAAqBGHNAAA="}} =
               ReplyMessage.run(
                 %{message_id: "AAMkAGI2TG93AAAqBGHNAAA=", comment: "Thanks for the update!"},
                 context
               )
    end

    test "returns error when message_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :message_id_required} = ReplyMessage.run(%{comment: "Hello"}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ReplyMessage.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified message was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ReplyMessage.run(%{message_id: "nonexistent", comment: "test"}, context)
    end
  end
end
