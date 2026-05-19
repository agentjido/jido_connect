defmodule Jido.Connect.MicrosoftOutlookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOutlook

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts

  @outlook_action_modules [
    Jido.Connect.MicrosoftOutlook.Actions.GetProfile,
    Jido.Connect.MicrosoftOutlook.Actions.ListMessages,
    Jido.Connect.MicrosoftOutlook.Actions.GetMessage,
    Jido.Connect.MicrosoftOutlook.Actions.ListFolders,
    Jido.Connect.MicrosoftOutlook.Actions.GetFolder,
    Jido.Connect.MicrosoftOutlook.Actions.SendMessage,
    Jido.Connect.MicrosoftOutlook.Actions.CreateDraft,
    Jido.Connect.MicrosoftOutlook.Actions.UpdateDraft,
    Jido.Connect.MicrosoftOutlook.Actions.SendDraft,
    Jido.Connect.MicrosoftOutlook.Actions.MoveMessage,
    Jido.Connect.MicrosoftOutlook.Actions.DeleteMessage,
    Jido.Connect.MicrosoftOutlook.Actions.DeleteDraft
  ]

  @outlook_dsl_fragments [
    Jido.Connect.MicrosoftOutlook.Actions.Read,
    Jido.Connect.MicrosoftOutlook.Actions.Write,
    Jido.Connect.MicrosoftOutlook.Actions.Destructive
  ]

  test "declares Microsoft Outlook Mail provider metadata" do
    spec = MicrosoftOutlook.integration()

    assert spec.id == :microsoft_outlook
    assert spec.package == :jido_connect_microsoft_outlook
    assert spec.name == "Microsoft Outlook Mail"
    assert spec.category == :email
    assert spec.tags == [:microsoft, :outlook, :email, :productivity]

    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftOutlook,
      id_prefix: "microsoft.outlook.",
      pack_id_prefix: "microsoft_outlook_",
      module_namespace: Jido.Connect.MicrosoftOutlook
    )

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "Mail.Read" in profile.optional_scopes
    assert "Mail.ReadBasic" in profile.optional_scopes
    assert "Mail.ReadWrite" in profile.optional_scopes
    assert "Mail.Send" in profile.optional_scopes
    assert "MailboxSettings.Read" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "microsoft.outlook.profile.get",
             "microsoft.outlook.messages.list",
             "microsoft.outlook.message.get",
             "microsoft.outlook.folders.list",
             "microsoft.outlook.folder.get",
             "microsoft.outlook.message.send",
             "microsoft.outlook.draft.create",
             "microsoft.outlook.draft.update",
             "microsoft.outlook.draft.send",
             "microsoft.outlook.message.move",
             "microsoft.outlook.message.delete",
             "microsoft.outlook.draft.delete"
           ]

    send_action = Enum.find(spec.actions, &(&1.id == "microsoft.outlook.message.send"))
    assert send_action.risk == :external_write
    assert send_action.confirmation == :required_for_ai

    update_draft_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.outlook.draft.update"))

    assert update_draft_action.risk == :write
    assert update_draft_action.confirmation == :required_for_ai

    delete_message_action =
      Enum.find(spec.actions, &(&1.id == "microsoft.outlook.message.delete"))

    assert delete_message_action.risk == :destructive
    assert delete_message_action.confirmation == :always
  end

  test "compiles generated Jido modules for actions and plugin" do
    ConnectorContracts.assert_generated_surface(MicrosoftOutlook,
      otp_app: :jido_connect_microsoft_outlook,
      action_modules: @outlook_action_modules,
      sensor_specs: [],
      plugin_module: Jido.Connect.MicrosoftOutlook.Plugin,
      plugin_name: "microsoft_outlook"
    )

    ConnectorContracts.assert_catalog_pack_delegates(MicrosoftOutlook,
      metadata_pack: :microsoft_outlook_metadata,
      triage_pack: :microsoft_outlook_triage,
      send_pack: :microsoft_outlook_send,
      destructive_pack: :microsoft_outlook_destructive
    )

    ConnectorContracts.assert_plugin_tool_availability(MicrosoftOutlook)
  end

  test "loads Outlook Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@outlook_dsl_fragments)
  end

  test "resolves Outlook scopes for read and send actions" do
    resolver = Jido.Connect.MicrosoftOutlook.ScopeResolver

    ConnectorContracts.assert_scope_resolver_shape(resolver, ["Mail.Read"])

    assert resolver.required_scopes(
             %{id: "microsoft.outlook.message.send"},
             %{},
             %{scopes: ["Mail.Send"]}
           ) == ["Mail.Send"]

    assert resolver.required_scopes(
             %{id: "microsoft.outlook.draft.create"},
             %{},
             %{scopes: ["Mail.ReadWrite"]}
           ) == ["Mail.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.outlook.message.get"},
             %{},
             %{scopes: ["Mail.Read"]}
           ) == ["Mail.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.outlook.message.move"},
             %{},
             %{scopes: ["Mail.ReadWrite"]}
           ) == ["Mail.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.outlook.message.delete"},
             %{},
             %{scopes: ["Mail.ReadWrite"]}
           ) == ["Mail.ReadWrite"]

    assert resolver.required_scopes(%{}, %{}, %{}) == ["Mail.Read"]
  end

  test "shell handlers return not implemented" do
    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetProfile.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListMessages.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetMessage.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListFolders.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetFolder.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendMessage.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.CreateDraft.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.UpdateDraft.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendDraft.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.MoveMessage.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.DeleteMessage.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftOutlook.Handlers.Actions.DeleteDraft.run(%{}, %{})
  end
end
