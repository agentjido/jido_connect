defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListItemsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.{GetListItem, ListListItems}

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

  test "lists items with selected fields and a structured filter", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites/site-1/lists/list-1/items"
      assert conn.query_params["$expand"] == "fields(select=Title,Status)"
      assert conn.query_params["$filter"] == "fields/Status eq 'Open'"
      assert conn.query_params["$top"] == "10"
      Req.Test.json(conn, %{"value" => [item_payload()]})
    end)

    assert {:ok, %{items: [item]}} =
             ListListItems.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 fields: ["Title", "Status"],
                 filter_field: "Status",
                 filter_operator: "eq",
                 filter_value: "Open",
                 page_size: 10
               },
               context
             )

    assert item.item_id == "42"
    assert item.fields["Title"] == "Replace printer"
  end

  test "gets one list item with fields", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites/site-1/lists/list-1/items/42"
      assert conn.query_params["$expand"] == "fields(select=Title)"
      Req.Test.json(conn, item_payload())
    end)

    assert {:ok, %{item: item}} =
             GetListItem.run(
               %{site_id: "site-1", list_id: "list-1", item_id: "42", fields: ["Title"]},
               context
             )

    assert item.etag == "\"42,3\""
  end

  test "escapes string filter literals", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.query_params["$filter"] == "fields/Title eq 'Director''s request'"
      Req.Test.json(conn, %{"value" => []})
    end)

    assert {:ok, %{items: []}} =
             ListListItems.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 filter_field: "Title",
                 filter_operator: "eq",
                 filter_value: "Director's request"
               },
               context
             )
  end

  test "rejects raw filter injection", %{context: context} do
    assert {:error, %Error.ConfigError{key: :filter_field}} =
             ListListItems.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 filter_field: "Title) or true",
                 filter_operator: "eq",
                 filter_value: "x"
               },
               context
             )
  end

  test "normalizes Graph errors and missing tokens", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{"error" => %{"message" => "Access denied"}})
    end)

    assert {:error, %Error.ProviderError{provider: :microsoft, status: 403}} =
             GetListItem.run(%{site_id: "site-1", list_id: "list-1", item_id: "42"}, context)

    assert {:error, :missing_access_token} = ListListItems.run(%{}, %{})
    assert {:error, :missing_access_token} = GetListItem.run(%{}, %{})
  end

  defp item_payload do
    %{
      "id" => "42",
      "name" => "42_.000",
      "eTag" => "\"42,3\"",
      "fields" => %{"Title" => "Replace printer", "Status" => "Open"}
    }
  end
end
