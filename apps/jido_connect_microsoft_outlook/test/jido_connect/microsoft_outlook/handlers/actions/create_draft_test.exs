defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.CreateDraftTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.CreateDraft

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
    test "creates a draft with subject and body" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["subject"] == "Draft subject"
        assert decoded["body"]["contentType"] == "text"
        assert decoded["body"]["content"] == "Draft body"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "AAMkAGI2TG93AAAqBGDRAAA=",
          "subject" => "Draft subject",
          "bodyPreview" => "Draft body",
          "isDraft" => true,
          "isRead" => true,
          "hasAttachments" => false,
          "body" => %{
            "contentType" => "text",
            "content" => "Draft body"
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
               CreateDraft.run(%{subject: "Draft subject", body: "Draft body"}, context)

      assert draft.message_id == "AAMkAGI2TG93AAAqBGDRAAA="
      assert draft.subject == "Draft subject"
      assert draft.is_draft == true
    end

    test "creates a draft with recipients and HTML content type" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["toRecipients"] == [
                 %{"emailAddress" => %{"address" => "user@example.com"}}
               ]

        assert decoded["body"]["contentType"] == "html"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "AAMkAGI2TG93AAAqBGDRBBB=",
          "subject" => "HTML draft",
          "isDraft" => true,
          "isRead" => true,
          "hasAttachments" => false,
          "body" => %{"contentType" => "html", "content" => "<p>Hello</p>"},
          "toRecipients" => [%{"emailAddress" => %{"address" => "user@example.com"}}],
          "ccRecipients" => [],
          "bccRecipients" => [],
          "sender" => %{},
          "from" => %{},
          "parentFolderId" => "AAMkAGI2TG93AAA="
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{draft: draft}} =
               CreateDraft.run(
                 %{
                   subject: "HTML draft",
                   body: "<p>Hello</p>",
                   content_type: "html",
                   to: ["user@example.com"]
                 },
                 context
               )

      assert draft.message_id == "AAMkAGI2TG93AAAqBGDRBBB="
    end

    test "creates a draft with minimal fields" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        refute Map.has_key?(decoded, "subject")
        refute Map.has_key?(decoded, "body")

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "AAMkAGI2TG93AAAqBGDRCCC=",
          "isDraft" => true,
          "isRead" => true,
          "hasAttachments" => false,
          "toRecipients" => [],
          "ccRecipients" => [],
          "bccRecipients" => [],
          "sender" => %{},
          "from" => %{},
          "body" => %{},
          "parentFolderId" => "AAMkAGI2TG93AAA="
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{draft: draft}} = CreateDraft.run(%{}, context)
      assert draft.message_id == "AAMkAGI2TG93AAAqBGDRCCC="
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = CreateDraft.run(%{}, %{})
    end

    test "returns error for HTTP 400" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(400), %{
          "error" => %{"message" => "Invalid request body."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               CreateDraft.run(%{subject: "test"}, context)
    end
  end
end
