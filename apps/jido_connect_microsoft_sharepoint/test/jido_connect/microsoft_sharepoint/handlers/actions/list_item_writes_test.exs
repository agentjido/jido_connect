defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListItemWritesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error

  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.{
    CreateListItem,
    DeleteListItem,
    UpdateListItem
  }

  alias Jido.Connect.MicrosoftSharepoint.Previews

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

  test "creates a list item from validated fields", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/sites/site-1/lists/list-1/items"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"fields" => %{"Status" => "Open", "Title" => "Printer"}}

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(item_payload())
    end)

    assert {:ok, %{item: item}} =
             CreateListItem.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 fields: %{Title: "Printer", Status: "Open"}
               },
               context
             )

    assert item.item_id == "42"
    assert item.fields["Title"] == "Printer"
  end

  test "updates list item fields with an ETag", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/sites/site-1/lists/list-1/items/42/fields"
      assert Plug.Conn.get_req_header(conn, "if-match") == ["\"42,3\""]
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"Status" => "Done"}
      Req.Test.json(conn, %{"@odata.etag" => "\"42,4\"", "Status" => "Done"})
    end)

    assert {:ok, %{item: item}} =
             UpdateListItem.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 item_id: "42",
                 etag: "\"42,3\"",
                 fields: %{"Status" => "Done"}
               },
               context
             )

    assert item.item_id == "42"
    assert item.etag == "\"42,4\""
    assert item.fields == %{"Status" => "Done"}
  end

  test "deletes a list item with an ETag", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/sites/site-1/lists/list-1/items/42"
      assert Plug.Conn.get_req_header(conn, "if-match") == ["\"42,3\""]
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{deleted: true, item_id: "42"}} =
             DeleteListItem.run(
               %{site_id: "site-1", list_id: "list-1", item_id: "42", etag: "\"42,3\""},
               context
             )
  end

  test "rejects invalid write input before a request", %{context: context} do
    assert {:error, %Error.ConfigError{key: :fields}} =
             CreateListItem.run(
               %{site_id: "site-1", list_id: "list-1", fields: %{"Title)" => "bad"}},
               context
             )

    assert {:error, %Error.ConfigError{key: :etag}} =
             UpdateListItem.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 item_id: "42",
                 etag: " ",
                 fields: %{"Title" => "Printer"}
               },
               context
             )
  end

  test "normalizes ETag conflicts and missing tokens", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(412)
      |> Req.Test.json(%{"error" => %{"message" => "The item changed"}})
    end)

    assert {:error, %Error.ProviderError{provider: :microsoft, status: 412}} =
             DeleteListItem.run(
               %{site_id: "site-1", list_id: "list-1", item_id: "42", etag: "\"42,3\""},
               context
             )

    assert {:error, :missing_access_token} = CreateListItem.run(%{}, %{})
    assert {:error, :missing_access_token} = UpdateListItem.run(%{}, %{})
    assert {:error, :missing_access_token} = DeleteListItem.run(%{}, %{})
  end

  test "write previews omit field values" do
    input = %{
      site_id: "site-1",
      list_id: "list-1",
      item_id: "42",
      etag: "\"42,3\"",
      fields: %{"Title" => "private value", "Status" => "Open"}
    }

    create = Previews.CreateListItem.preview(input, %{})
    update = Previews.UpdateListItem.preview(input, %{})
    delete = Previews.DeleteListItem.preview(input, %{})

    assert create.field_names == ["Status", "Title"]
    assert create.field_count == 2
    assert update.field_names == ["Status", "Title"]
    assert delete.item_id == "42"

    refute inspect(create) =~ "private value"
    refute inspect(update) =~ "private value"
  end

  defp item_payload do
    %{
      "id" => "42",
      "eTag" => "\"42,3\"",
      "fields" => %{"Title" => "Printer", "Status" => "Open"}
    }
  end
end
