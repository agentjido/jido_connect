defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendMessageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendMessage

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
    test "sends a new message with to, subject, and body" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/sendMail"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        msg = decoded["message"]

        assert msg["subject"] == "Test subject"
        assert msg["body"]["contentType"] == "text"
        assert msg["body"]["content"] == "Hello world"
        assert msg["toRecipients"] == [%{"emailAddress" => %{"address" => "user@example.com"}}]

        conn |> Plug.Conn.put_status(202) |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{sent: true}} =
               SendMessage.run(
                 %{to: ["user@example.com"], subject: "Test subject", body: "Hello world"},
                 context
               )
    end

    test "sends a message with cc, bcc, and reply_to" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        msg = decoded["message"]

        assert msg["ccRecipients"] == [%{"emailAddress" => %{"address" => "cc@example.com"}}]
        assert msg["bccRecipients"] == [%{"emailAddress" => %{"address" => "bcc@example.com"}}]
        assert msg["replyTo"] == [%{"emailAddress" => %{"address" => "reply@example.com"}}]

        conn |> Plug.Conn.put_status(202) |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{sent: true}} =
               SendMessage.run(
                 %{
                   to: ["user@example.com"],
                   subject: "Test",
                   body: "Body",
                   cc: ["cc@example.com"],
                   bcc: ["bcc@example.com"],
                   reply_to: ["reply@example.com"]
                 },
                 context
               )
    end

    test "sends an HTML message" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        msg = decoded["message"]

        assert msg["body"]["contentType"] == "html"
        assert msg["body"]["content"] == "<p>Hello</p>"

        conn |> Plug.Conn.put_status(202) |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{sent: true}} =
               SendMessage.run(
                 %{
                   to: ["user@example.com"],
                   subject: "HTML message",
                   body: "<p>Hello</p>",
                   content_type: "html"
                 },
                 context
               )
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = SendMessage.run(%{}, %{})
    end

    test "returns error for HTTP 400" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(400), %{
          "error" => %{"message" => "Invalid request body."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               SendMessage.run(%{to: ["user@example.com"]}, context)
    end
  end
end
