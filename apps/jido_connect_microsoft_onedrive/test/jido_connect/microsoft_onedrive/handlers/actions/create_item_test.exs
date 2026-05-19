defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItemTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem

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
    test "creates a folder in drive root" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/drive/root/children"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert %{"name" => "New Folder", "folder" => %{}} = Jason.decode!(body)

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "01NEW1",
          "name" => "New Folder",
          "folder" => %{"childCount" => 0},
          "parentReference" => %{"driveId" => "b!DRIVE1"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{item: item}} =
               CreateItem.run(%{name: "New Folder", type: "folder"}, context)

      assert item.item_id == "01NEW1"
      assert item.name == "New Folder"
      assert item.folder.child_count == 0
    end

    test "creates a folder under a specific parent" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/drive/items/01PARENT/children"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "01CHILD1",
          "name" => "Sub Folder",
          "folder" => %{"childCount" => 0}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{item: item}} =
               CreateItem.run(
                 %{name: "Sub Folder", type: "folder", parent_id: "01PARENT"},
                 context
               )

      assert item.item_id == "01CHILD1"
      assert item.name == "Sub Folder"
    end

    test "returns error when name is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :name_required} = CreateItem.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = CreateItem.run(%{}, %{})
    end

    test "returns error for HTTP 400" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(400), %{
          "error" => %{"message" => "Invalid request body"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               CreateItem.run(%{name: "Bad Item"}, context)
    end
  end
end
