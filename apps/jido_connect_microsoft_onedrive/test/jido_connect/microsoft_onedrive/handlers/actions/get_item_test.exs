defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetItemTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetItem

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
    test "fetches a single drive item by id" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drive/items/01ABCD1234"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "01ABCD1234",
          "name" => "Quarterly Report.docx",
          "size" => 1024,
          "webUrl" =>
            "https://contoso-my.sharepoint.com/personal/user/Documents/Quarterly Report.docx",
          "createdDateTime" => "2026-05-19T10:00:00Z",
          "lastModifiedDateTime" => "2026-05-19T12:00:00Z",
          "file" => %{
            "mimeType" =>
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "hashes" => %{"sha1Hash" => "ABC123"}
          },
          "parentReference" => %{"driveId" => "b!DRIVE1"},
          "createdBy" => %{
            "user" => %{"displayName" => "Adele Vance", "email" => "adele@contoso.com"}
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{item: item}} = GetItem.run(%{item_id: "01ABCD1234"}, context)

      assert item.item_id == "01ABCD1234"
      assert item.name == "Quarterly Report.docx"
      assert item.size == 1024
      assert item.file.mime_type =~ "wordprocessingml"
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :item_id_required} = GetItem.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetItem.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified item was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetItem.run(%{item_id: "nonexistent"}, context)
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{"code" => "accessDenied", "message" => "Access is denied."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               GetItem.run(%{item_id: "restricted"}, context)
    end
  end
end
