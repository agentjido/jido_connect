defmodule Jido.Connect.MicrosoftSharepointTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftSharepoint
  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts

  @action_modules [
    Jido.Connect.MicrosoftSharepoint.Actions.ResolveSite,
    Jido.Connect.MicrosoftSharepoint.Actions.GetSite,
    Jido.Connect.MicrosoftSharepoint.Actions.SearchSites,
    Jido.Connect.MicrosoftSharepoint.Actions.ListLists,
    Jido.Connect.MicrosoftSharepoint.Actions.GetList,
    Jido.Connect.MicrosoftSharepoint.Actions.ListColumns,
    Jido.Connect.MicrosoftSharepoint.Actions.ListListItems,
    Jido.Connect.MicrosoftSharepoint.Actions.GetListItem
  ]

  @fragments [
    Jido.Connect.MicrosoftSharepoint.Actions.Sites,
    Jido.Connect.MicrosoftSharepoint.Actions.Lists,
    Jido.Connect.MicrosoftSharepoint.Actions.ListItems
  ]

  test "declares SharePoint provider metadata and auth profiles" do
    spec = MicrosoftSharepoint.integration()

    assert spec.id == :microsoft_sharepoint
    assert spec.package == :jido_connect_microsoft_sharepoint
    assert spec.name == "Microsoft SharePoint"
    assert spec.category == :productivity
    assert spec.tags == [:microsoft, :sharepoint, :sites, :lists, :documents]

    assert Enum.map(spec.actions, & &1.id) == [
             "microsoft.sharepoint.site.resolve",
             "microsoft.sharepoint.site.get",
             "microsoft.sharepoint.sites.search",
             "microsoft.sharepoint.lists.list",
             "microsoft.sharepoint.list.get",
             "microsoft.sharepoint.list.columns.list",
             "microsoft.sharepoint.list.items.list",
             "microsoft.sharepoint.list.item.get"
           ]

    assert spec.triggers == []

    assert [%{id: :user} = user, %{id: :application} = application] = spec.auth_profiles
    assert user.default?
    assert user.refresh?
    assert "Sites.Read.All" in user.optional_scopes
    assert application.setup == :oauth2_client_credentials
    assert application.owner == :tenant
    assert application.lease_fields == [:access_token]

    ConnectorContracts.assert_generated_surface(MicrosoftSharepoint,
      otp_app: :jido_connect_microsoft_sharepoint,
      action_modules: @action_modules,
      sensor_specs: [],
      plugin_module: Jido.Connect.MicrosoftSharepoint.Plugin,
      plugin_name: "microsoft_sharepoint"
    )
  end

  test "loads capability-oriented Spark fragments" do
    ConnectorContracts.assert_spark_fragments(@fragments)
  end

  test "resolves tenant-wide and selected SharePoint read scopes" do
    resolver = Jido.Connect.MicrosoftSharepoint.ScopeResolver

    assert resolver.required_scopes(%{}, %{}, %{}) == ["Sites.Read.All"]

    assert resolver.required_scopes(
             %{id: "microsoft.sharepoint.site.get"},
             %{},
             %{scopes: ["Sites.Selected"]}
           ) == ["Sites.Selected"]

    assert resolver.required_scopes(
             %{id: "microsoft.sharepoint.list.items.list"},
             %{},
             %{scopes: ["Lists.SelectedOperations.Selected"]}
           ) == ["Lists.SelectedOperations.Selected"]

    assert resolver.required_scopes(
             %{id: "microsoft.sharepoint.list.item.get"},
             %{},
             %{scopes: ["ListItems.SelectedOperations.Selected"]}
           ) == ["ListItems.SelectedOperations.Selected"]

    assert resolver.required_scopes(
             %{id: "microsoft.sharepoint.sites.search"},
             %{},
             %{scopes: ["Sites.Selected"]}
           ) == ["Sites.Read.All"]
  end
end
