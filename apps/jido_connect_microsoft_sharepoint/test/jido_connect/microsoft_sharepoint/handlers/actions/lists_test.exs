defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.{GetList, ListColumns, ListLists}

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

    {:ok, context: %{credentials: %{access_token: "test-token"}}}
  end

  test "lists site lists", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites/site-1/lists"
      assert conn.query_params["$top"] == "20"
      Req.Test.json(conn, %{"value" => [list_payload()]})
    end)

    assert {:ok, %{lists: [list], next_link: nil}} =
             ListLists.run(%{site_id: "site-1", page_size: 20}, context)

    assert list.display_name == "Requests"
  end

  test "gets one site list", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites/site-1/lists/list-1"
      Req.Test.json(conn, list_payload())
    end)

    assert {:ok, %{list: list}} =
             GetList.run(%{site_id: "site-1", list_id: "list-1"}, context)

    assert list.list_id == "list-1"
  end

  test "lists columns", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites/site-1/lists/list-1/columns"

      Req.Test.json(conn, %{
        "value" => [
          %{
            "id" => "column-1",
            "name" => "Status",
            "displayName" => "Status",
            "indexed" => true,
            "choice" => %{"choices" => ["Open", "Closed"]}
          }
        ]
      })
    end)

    assert {:ok, %{columns: [column]}} =
             ListColumns.run(%{site_id: "site-1", list_id: "list-1"}, context)

    assert column.column_type == "choice"
    assert column.indexed
  end

  test "returns stable missing-token errors" do
    assert {:error, :missing_access_token} = ListLists.run(%{}, %{})
    assert {:error, :missing_access_token} = GetList.run(%{}, %{})
    assert {:error, :missing_access_token} = ListColumns.run(%{}, %{})
  end

  defp list_payload do
    %{
      "id" => "list-1",
      "name" => "Requests",
      "displayName" => "Requests",
      "list" => %{"template" => "genericList"}
    }
  end
end
