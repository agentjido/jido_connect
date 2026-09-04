defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.SitesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error

  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.{
    GetSite,
    ResolveSite,
    SearchSites
  }

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

  test "resolves a site by hostname and path", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/sites/contoso.sharepoint.com:/sites/operations"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
      Req.Test.json(conn, site_payload())
    end)

    assert {:ok, %{site: site}} =
             ResolveSite.run(
               %{hostname: "contoso.sharepoint.com", relative_path: "/sites/operations"},
               context
             )

    assert site.display_name == "Operations"
  end

  test "gets a site by id", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites/contoso.sharepoint.com%2Csite%2Cweb"
      Req.Test.json(conn, site_payload())
    end)

    assert {:ok, %{site: site}} =
             GetSite.run(%{site_id: "contoso.sharepoint.com,site,web"}, context)

    assert site.site_id == "contoso.sharepoint.com,site,web"
  end

  test "searches sites with paging", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/sites"
      assert conn.query_params["search"] == "operations"
      assert conn.query_params["$top"] == "10"

      Req.Test.json(conn, %{
        "value" => [site_payload()],
        "@odata.nextLink" => "https://graph.test/sites?search=operations&$skiptoken=next"
      })
    end)

    assert {:ok, %{sites: [site], next_link: next_link}} =
             SearchSites.run(%{query: "operations", page_size: 10}, context)

    assert site.display_name == "Operations"
    assert next_link =~ "skiptoken"
  end

  test "rejects invalid paths and missing tokens", %{context: context} do
    assert {:error, %Error.ConfigError{key: :hostname}} =
             ResolveSite.run(%{hostname: "bad/host", relative_path: "/sites/ops"}, context)

    assert {:error, :missing_access_token} = GetSite.run(%{site_id: "site"}, %{})
    assert {:error, :missing_access_token} = ResolveSite.run(%{}, %{})
    assert {:error, :missing_access_token} = SearchSites.run(%{}, %{})
  end

  defp site_payload do
    %{
      "id" => "contoso.sharepoint.com,site,web",
      "name" => "operations",
      "displayName" => "Operations",
      "webUrl" => "https://contoso.sharepoint.com/sites/operations"
    }
  end
end
