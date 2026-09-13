defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListItemDeltaTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.DeltaListItems
  alias Jido.Connect.MicrosoftSharepoint.DeltaCursor

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

  test "reads list item changes with fields and a delta token", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/sites/site-1/lists/list-1/items/delta"
      assert conn.query_params["$expand"] == "fields(select=Title,Status)"
      assert conn.query_params["$top"] == "10"
      assert conn.query_params["token"] == "latest"

      Req.Test.json(conn, %{
        "@odata.deltaLink" =>
          "https://graph.microsoft.com/v1.0/sites/site-1/lists/list-1/items/delta?token=next",
        "value" => [
          %{"id" => "42", "eTag" => "\"42,3\"", "fields" => %{"Title" => "Printer"}},
          %{"id" => "43", "deleted" => %{"state" => "deleted"}}
        ]
      })
    end)

    assert {:ok, %{items: [changed, deleted], delta_link: delta_link, next_link: nil}} =
             DeltaListItems.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 fields: ["Title", "Status"],
                 page_size: 10,
                 token: "latest"
               },
               context
             )

    assert changed.fields["Title"] == "Printer"
    assert deleted.deleted
    assert delta_link =~ "token=next"
  end

  test "returns a next page link while enumeration continues", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.query_params["$skiptoken"] == "page-2"

      Req.Test.json(conn, %{
        "@odata.nextLink" =>
          "https://graph.test/sites/site-1/lists/list-1/items/delta?%24skiptoken=page-3",
        "value" => []
      })
    end)

    assert {:ok, %{items: [], next_link: next_link, delta_link: nil}} =
             DeltaListItems.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 cursor:
                   "https://graph.test/sites/site-1/lists/list-1/items/delta?%24skiptoken=page-2"
               },
               context
             )

    assert next_link =~ "page-3"
  end

  test "validates tokens and normalizes reset responses", %{context: context} do
    assert {:error, %Error.ConfigError{key: :token}} =
             DeltaListItems.run(%{site_id: "site-1", list_id: "list-1", token: " "}, context)

    assert {:error, %Error.ConfigError{key: :cursor}} =
             DeltaListItems.run(
               %{
                 site_id: "site-1",
                 list_id: "list-1",
                 cursor: "https://example.com/steal"
               },
               context
             )

    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(410)
      |> Plug.Conn.put_resp_header("location", "https://graph.microsoft.com/v1.0/restart")
      |> Req.Test.json(%{"error" => %{"code" => "resyncRequired", "message" => "Restart"}})
    end)

    assert {:error, %Error.ProviderError{provider: :microsoft, status: 410}} =
             DeltaListItems.run(%{site_id: "site-1", list_id: "list-1"}, context)

    assert {:error, :missing_access_token} = DeltaListItems.run(%{}, %{})
  end

  test "accepts the equivalent escaped Graph resource path" do
    assert {:ok, _cursor} =
             DeltaCursor.validate(
               "https://graph.test/sites/contoso,site/lists/list-1/items/delta?token=next",
               "/sites/contoso%2Csite/lists/list-1/items/delta"
             )
  end
end
