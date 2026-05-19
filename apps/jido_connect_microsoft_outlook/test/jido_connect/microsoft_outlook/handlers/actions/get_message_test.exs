defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetMessageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetMessage

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
    test "fetches a single message by id" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/messages/AAMkAGI2TG93AAAqBGHNAAA="
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "AAMkAGI2TG93AAAqBGHNAAA=",
          "conversationId" => "AAQkAGI2NGVh",
          "subject" => "Quarterly budget review",
          "bodyPreview" => "Hi team, Please review the attached quarterly budget.",
          "importance" => "normal",
          "isRead" => false,
          "isDraft" => false,
          "hasAttachments" => true,
          "internetMessageId" => "<CWYP123@contoso.com>",
          "receivedDateTime" => "2026-05-19T12:00:00Z",
          "sentDateTime" => "2026-05-19T11:59:00Z",
          "parentFolderId" => "AAMkAGI2TG93AAA=",
          "sender" => %{
            "emailAddress" => %{
              "name" => "Megan Bowen",
              "address" => "meganb@contoso.com"
            }
          },
          "from" => %{
            "emailAddress" => %{
              "name" => "Megan Bowen",
              "address" => "meganb@contoso.com"
            }
          },
          "toRecipients" => [
            %{
              "emailAddress" => %{
                "name" => "All Users",
                "address" => "allusers@contoso.com"
              }
            }
          ],
          "ccRecipients" => [],
          "bccRecipients" => [],
          "body" => %{
            "contentType" => "html",
            "content" => "<html><body><p>Hi team</p></body></html>"
          },
          "attachments" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{message: message}} =
               GetMessage.run(%{message_id: "AAMkAGI2TG93AAAqBGHNAAA="}, context)

      assert message.message_id == "AAMkAGI2TG93AAAqBGHNAAA="
      assert message.subject == "Quarterly budget review"
      assert message.is_read == false
      assert message.has_attachments == true
      assert message.sender == %{name: "Megan Bowen", address: "meganb@contoso.com"}
    end

    test "returns error when message_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :message_id_required} = GetMessage.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetMessage.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified message was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetMessage.run(%{message_id: "nonexistent"}, context)
    end
  end
end
