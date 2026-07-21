defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListFoldersTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListFolders

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
    test "lists folders successfully" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/mailFolders"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert conn.query_params["$top"] == "25"

        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#users('user')/mailFolders",
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/mailFolders?$skip=10",
          "value" => [
            %{
              "id" => "AAMkAGI2TG93AAA=",
              "displayName" => "Inbox",
              "parentFolderId" => "AAMkAGI2AABhAAA=",
              "childFolderCount" => 2,
              "unreadItemCount" => 5,
              "totalItemCount" => 42,
              "wellKnownName" => "inbox"
            },
            %{
              "id" => "AAMkAGI2TG94BBB=",
              "displayName" => "Sent Items",
              "parentFolderId" => "AAMkAGI2AABhAAA=",
              "childFolderCount" => 0,
              "unreadItemCount" => 0,
              "totalItemCount" => 18,
              "wellKnownName" => "sentitems"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{folders: folders, next_link: next_link}} =
               ListFolders.run(%{}, context)

      assert length(folders) == 2
      assert [%{display_name: "Inbox"}, %{display_name: "Sent Items"}] = folders
      assert next_link =~ "$skip=10"
    end

    test "passes custom page_size" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$top"] == "10"

        Req.Test.json(conn, %{
          "value" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{folders: []}} = ListFolders.run(%{page_size: 10}, context)
    end

    test "handles empty folder list" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#users('user')/mailFolders",
          "value" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{folders: [], next_link: nil}} = ListFolders.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListFolders.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(401), %{
          "error" => %{"message" => "Invalid authentication token"}
        })
      end)

      context = %{credentials: %{access_token: "bad-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListFolders.run(%{}, context)
    end
  end
end
