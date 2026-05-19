defmodule Jido.Connect.MicrosoftOnedriveTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOnedrive

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts

  @onedrive_action_modules [
    Jido.Connect.MicrosoftOnedrive.Actions.ListItems,
    Jido.Connect.MicrosoftOnedrive.Actions.GetItem,
    Jido.Connect.MicrosoftOnedrive.Actions.GetDrive,
    Jido.Connect.MicrosoftOnedrive.Actions.ListDrives,
    Jido.Connect.MicrosoftOnedrive.Actions.Search,
    Jido.Connect.MicrosoftOnedrive.Actions.DownloadContent,
    Jido.Connect.MicrosoftOnedrive.Actions.Delta,
    Jido.Connect.MicrosoftOnedrive.Actions.CreateItem,
    Jido.Connect.MicrosoftOnedrive.Actions.UpdateItem,
    Jido.Connect.MicrosoftOnedrive.Actions.UploadItem,
    Jido.Connect.MicrosoftOnedrive.Actions.DeleteItem
  ]

  @onedrive_dsl_fragments [
    Jido.Connect.MicrosoftOnedrive.Actions.Read,
    Jido.Connect.MicrosoftOnedrive.Actions.Write,
    Jido.Connect.MicrosoftOnedrive.Actions.Destructive
  ]

  test "declares Microsoft OneDrive provider metadata" do
    spec = MicrosoftOnedrive.integration()

    assert spec.id == :microsoft_onedrive
    assert spec.package == :jido_connect_microsoft_onedrive
    assert spec.name == "Microsoft OneDrive"
    assert spec.category == :file_storage
    assert spec.tags == [:microsoft, :onedrive, :files, :storage]

    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftOnedrive,
      id_prefix: "microsoft.onedrive.",
      pack_id_prefix: "microsoft_onedrive_",
      module_namespace: Jido.Connect.MicrosoftOnedrive
    )

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "Files.Read" in profile.optional_scopes
    assert "Files.Read.All" in profile.optional_scopes
    assert "Files.ReadWrite" in profile.optional_scopes
    assert "Files.ReadWrite.All" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "microsoft.onedrive.items.list",
             "microsoft.onedrive.item.get",
             "microsoft.onedrive.drive.get",
             "microsoft.onedrive.drives.list",
             "microsoft.onedrive.items.search",
             "microsoft.onedrive.item.download",
             "microsoft.onedrive.items.delta",
             "microsoft.onedrive.item.create",
             "microsoft.onedrive.item.update",
             "microsoft.onedrive.item.upload",
             "microsoft.onedrive.item.delete"
           ]

    create_action = Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.create"))
    assert create_action.risk == :external_write
    assert create_action.confirmation == :required_for_ai

    update_action = Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.update"))
    assert update_action.risk == :write
    assert update_action.confirmation == :required_for_ai

    upload_action = Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.upload"))
    assert upload_action.risk == :external_write
    assert upload_action.confirmation == :required_for_ai

    delete_action = Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always
  end

  test "compiles generated Jido modules for actions and plugin" do
    ConnectorContracts.assert_generated_surface(MicrosoftOnedrive,
      otp_app: :jido_connect_microsoft_onedrive,
      action_modules: @onedrive_action_modules,
      sensor_specs: [],
      plugin_module: Jido.Connect.MicrosoftOnedrive.Plugin,
      plugin_name: "microsoft_onedrive"
    )

    ConnectorContracts.assert_catalog_pack_delegates(MicrosoftOnedrive,
      metadata_pack: :microsoft_onedrive_metadata,
      triage_pack: :microsoft_onedrive_triage,
      write_pack: :microsoft_onedrive_write,
      destructive_pack: :microsoft_onedrive_destructive
    )

    ConnectorContracts.assert_plugin_tool_availability(MicrosoftOnedrive)
  end

  test "loads OneDrive Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@onedrive_dsl_fragments)
  end

  test "resolves OneDrive scopes for read and write actions" do
    resolver = Jido.Connect.MicrosoftOnedrive.ScopeResolver
    Code.ensure_loaded(resolver)

    ConnectorContracts.assert_scope_resolver_shape(resolver, ["Files.Read"])

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.create"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.update"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.upload"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.items.list"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.get"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.drive.get"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.items.search"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.download"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.items.delta"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.drives.list"},
             %{},
             %{scopes: ["Files.Read.All"]}
           ) == ["Files.Read.All"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.delete"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    assert resolver.required_scopes(%{}, %{}, %{}) == ["Files.Read"]
  end

  test "handlers return not_implemented in scaffold phase" do
    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItem.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItem.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem.run(%{}, %{})
  end
end
