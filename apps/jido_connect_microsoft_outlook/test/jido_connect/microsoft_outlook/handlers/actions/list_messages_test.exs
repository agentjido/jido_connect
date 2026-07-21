defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListMessagesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListMessages

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
    test "lists messages from inbox by default" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/mailFolders/inbox/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert conn.query_params["$top"] == "25"

        Req.Test.json(conn, %{
          "@odata.context" => "https://graph.microsoft.com/v1.0/$metadata#users('user')/messages",
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=25",
          "value" => [
            %{
              "id" => "AAMkAGI2TG93AAAqBGHNAAA=",
              "subject" => "Quarterly budget review",
              "bodyPreview" => "Hi team, Please review the attached quarterly budget.",
              "importance" => "normal",
              "isRead" => false,
              "isDraft" => false,
              "hasAttachments" => true,
              "receivedDateTime" => "2026-05-19T12:00:00Z",
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
              }
            },
            %{
              "id" => "AAMkAGI2TG93AAAqBGHOAAA=",
              "subject" => "Meeting notes",
              "bodyPreview" => "Here are the notes.",
              "importance" => "low",
              "isRead" => true,
              "isDraft" => false,
              "hasAttachments" => false,
              "receivedDateTime" => "2026-05-18T09:30:00Z",
              "parentFolderId" => "AAMkAGI2TG93AAA=",
              "sender" => %{
                "emailAddress" => %{
                  "name" => "Brian Johnson",
                  "address" => "brianj@contoso.com"
                }
              },
              "body" => %{
                "contentType" => "text",
                "content" => "Here are the notes."
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{messages: messages, next_link: next_link}} =
               ListMessages.run(%{}, context)

      assert length(messages) == 2
      assert [%{subject: "Quarterly budget review"}, %{subject: "Meeting notes"}] = messages
      assert next_link =~ "$skip=25"
    end

    test "lists messages from a specific folder" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/mailFolders/AAMkSentItems=/messages"

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "msg-sent-1",
              "subject" => "Re: Budget"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{messages: messages}} =
               ListMessages.run(%{folder_id: "AAMkSentItems="}, context)

      assert length(messages) == 1
    end

    test "passes search query via $search parameter" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$search"] == "\"budget review\""

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "msg-search-1",
              "subject" => "Quarterly budget review"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{messages: messages}} =
               ListMessages.run(%{query: "budget review"}, context)

      assert length(messages) == 1
    end

    test "passes page_size and skip parameters" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$top"] == "10"
        assert conn.query_params["$skip"] == "20"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{messages: []}} =
               ListMessages.run(%{page_size: 10, skip: 20}, context)
    end

    test "handles empty message list" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "@odata.context" => "https://graph.microsoft.com/v1.0/$metadata#users('user')/messages",
          "value" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{messages: [], next_link: nil}} = ListMessages.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListMessages.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListMessages.run(%{}, context)
    end
  end
end
