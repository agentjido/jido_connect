defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.UpdateDraftTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.UpdateDraft

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
    test "updates draft subject and body" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/me/messages/AAMkAGI2TG93AAAqBGDRAAA="
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["subject"] == "Updated subject"
        assert decoded["body"]["content"] == "Updated body"

        Req.Test.json(conn, %{
          "id" => "AAMkAGI2TG93AAAqBGDRAAA=",
          "subject" => "Updated subject",
          "bodyPreview" => "Updated body",
          "isDraft" => true,
          "isRead" => true,
          "hasAttachments" => false,
          "body" => %{
            "contentType" => "text",
            "content" => "Updated body"
          },
          "toRecipients" => [],
          "ccRecipients" => [],
          "bccRecipients" => [],
          "sender" => %{},
          "from" => %{},
          "parentFolderId" => "AAMkAGI2TG93AAA="
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{draft: draft}} =
               UpdateDraft.run(
                 %{
                   draft_id: "AAMkAGI2TG93AAAqBGDRAAA=",
                   subject: "Updated subject",
                   body: "Updated body"
                 },
                 context
               )

      assert draft.message_id == "AAMkAGI2TG93AAAqBGDRAAA="
      assert draft.subject == "Updated subject"
      assert draft.is_draft == true
    end

    test "updates draft recipients" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["toRecipients"] == [
                 %{"emailAddress" => %{"address" => "new@example.com"}}
               ]

        Req.Test.json(conn, %{
          "id" => "AAMkAGI2TG93AAAqBGDRAAA=",
          "subject" => nil,
          "isDraft" => true,
          "isRead" => true,
          "hasAttachments" => false,
          "toRecipients" => [%{"emailAddress" => %{"address" => "new@example.com"}}],
          "ccRecipients" => [],
          "bccRecipients" => [],
          "sender" => %{},
          "from" => %{},
          "body" => %{},
          "parentFolderId" => "AAMkAGI2TG93AAA="
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{draft: draft}} =
               UpdateDraft.run(
                 %{draft_id: "AAMkAGI2TG93AAAqBGDRAAA=", to: ["new@example.com"]},
                 context
               )

      assert draft.message_id == "AAMkAGI2TG93AAAqBGDRAAA="
    end

    test "returns error when draft_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :draft_id_required} = UpdateDraft.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = UpdateDraft.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified message was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               UpdateDraft.run(%{draft_id: "nonexistent"}, context)
    end
  end
end
