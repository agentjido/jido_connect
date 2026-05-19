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
    Jido.Connect.MicrosoftOnedrive.Actions.DeleteItem,
    Jido.Connect.MicrosoftOnedrive.Actions.CreateSharingLink,
    Jido.Connect.MicrosoftOnedrive.Actions.ListPermissions,
    Jido.Connect.MicrosoftOnedrive.Actions.GetPermission,
    Jido.Connect.MicrosoftOnedrive.Actions.CreatePermission,
    Jido.Connect.MicrosoftOnedrive.Actions.DeletePermission
  ]

  @onedrive_dsl_fragments [
    Jido.Connect.MicrosoftOnedrive.Actions.Read,
    Jido.Connect.MicrosoftOnedrive.Actions.Write,
    Jido.Connect.MicrosoftOnedrive.Actions.Destructive,
    Jido.Connect.MicrosoftOnedrive.Actions.Sharing,
    Jido.Connect.MicrosoftOnedrive.Actions.Permissions
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
             "microsoft.onedrive.item.delete",
             "microsoft.onedrive.item.create_link",
             "microsoft.onedrive.item.permissions.list",
             "microsoft.onedrive.item.permission.get",
             "microsoft.onedrive.item.permission.create",
             "microsoft.onedrive.item.permission.delete"
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

    create_link_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.create_link"))

    assert create_link_action.risk == :external_write
    assert create_link_action.confirmation == :always

    create_perm_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.permission.create"))

    assert create_perm_action.risk == :external_write
    assert create_perm_action.confirmation == :always

    delete_perm_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.permission.delete"))

    assert delete_perm_action.risk == :destructive
    assert delete_perm_action.confirmation == :always

    list_perms_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.permissions.list"))

    assert list_perms_action.risk == :read
    assert list_perms_action.confirmation == :none

    get_perm_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.onedrive.item.permission.get"))

    assert get_perm_action.risk == :read
    assert get_perm_action.confirmation == :none
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
      destructive_pack: :microsoft_onedrive_destructive,
      sharing_pack: :microsoft_onedrive_sharing,
      admin_pack: :microsoft_onedrive_admin
    )

    ConnectorContracts.assert_plugin_tool_availability(MicrosoftOnedrive)
  end

  test "loads OneDrive Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@onedrive_dsl_fragments)
  end

  test "resolves OneDrive scopes for read, write, sharing, and permission actions" do
    resolver = Jido.Connect.MicrosoftOnedrive.ScopeResolver
    Code.ensure_loaded(resolver)

    ConnectorContracts.assert_scope_resolver_shape(resolver, ["Files.Read"])

    # ── Write actions ─────────────────────────────────────────────────
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

    # ── Read actions ──────────────────────────────────────────────────
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

    # ── Destructive actions ───────────────────────────────────────────
    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.delete"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    # ── Sharing write actions ─────────────────────────────────────────
    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.create_link"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.permission.create"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    # ── Sharing read actions ──────────────────────────────────────────
    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.permissions.list"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.permission.get"},
             %{},
             %{scopes: ["Files.Read"]}
           ) == ["Files.Read"]

    # ── Permission destructive ────────────────────────────────────────
    assert resolver.required_scopes(
             %{id: "microsoft.onedrive.item.permission.delete"},
             %{},
             %{scopes: ["Files.ReadWrite"]}
           ) == ["Files.ReadWrite"]

    assert resolver.required_scopes(%{}, %{}, %{}) == ["Files.Read"]
  end

  test "write and destructive handlers reject missing access token" do
    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItem.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItem.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem.run(%{}, %{})
  end

  test "sharing and permission handlers reject missing access token" do
    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateSharingLink.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListPermissions.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetPermission.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreatePermission.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeletePermission.run(%{}, %{})
  end
end
