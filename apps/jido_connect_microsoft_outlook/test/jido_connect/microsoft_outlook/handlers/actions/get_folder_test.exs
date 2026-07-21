defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetFolderTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetFolder

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
    test "fetches a single folder by id" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/mailFolders/AAMkAGI2TG93AAA="
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "AAMkAGI2TG93AAA=",
          "displayName" => "Inbox",
          "parentFolderId" => "AAMkAGI2AABhAAA=",
          "childFolderCount" => 2,
          "unreadItemCount" => 5,
          "totalItemCount" => 42,
          "wellKnownName" => "inbox"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{folder: folder}} =
               GetFolder.run(%{folder_id: "AAMkAGI2TG93AAA="}, context)

      assert folder.folder_id == "AAMkAGI2TG93AAA="
      assert folder.display_name == "Inbox"
      assert folder.unread_item_count == 5
      assert folder.total_item_count == 42
      assert folder.well_known_name == "inbox"
    end

    test "returns error when folder_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :folder_id_required} = GetFolder.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetFolder.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified folder was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetFolder.run(%{folder_id: "nonexistent"}, context)
    end
  end
end
