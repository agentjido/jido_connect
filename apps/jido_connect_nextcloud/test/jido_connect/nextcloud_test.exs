defmodule Jido.Connect.NextcloudTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Nextcloud

  @action_ids [
    "nextcloud.files.list",
    "nextcloud.file.get",
    "nextcloud.files.search",
    "nextcloud.file.download",
    "nextcloud.folder.create",
    "nextcloud.file.upload",
    "nextcloud.node.move",
    "nextcloud.node.copy",
    "nextcloud.node.delete",
    "nextcloud.shares.list",
    "nextcloud.share.get",
    "nextcloud.share.create",
    "nextcloud.share.update",
    "nextcloud.share.delete",
    "nextcloud.sharees.search",
    "nextcloud.office.capabilities.get",
    "nextcloud.office.launch_token.get"
  ]

  test "declares Nextcloud provider metadata" do
    spec = Nextcloud.integration()

    assert spec.id == :nextcloud
    assert spec.package == :jido_connect_nextcloud
    assert spec.name == "Nextcloud"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert :nextcloud in spec.tags

    assert Enum.map(spec.actions, & &1.id) == @action_ids

    assert %{id: :app_password, kind: :api_key, default?: true} =
             Enum.find(spec.auth_profiles, &(&1.id == :app_password))

    assert %{id: :oauth2_user, kind: :oauth2, default?: false} =
             Enum.find(spec.auth_profiles, &(&1.id == :oauth2_user))
  end

  test "marks write, destructive, share, and office launch actions with confirmation" do
    actions = Map.new(Nextcloud.integration().actions, &{&1.id, &1})

    assert actions["nextcloud.folder.create"].risk == :external_write
    assert actions["nextcloud.folder.create"].confirmation == :required_for_ai
    assert actions["nextcloud.file.upload"].confirmation == :required_for_ai
    assert actions["nextcloud.node.move"].confirmation == :required_for_ai
    assert actions["nextcloud.node.copy"].confirmation == :required_for_ai

    assert actions["nextcloud.node.delete"].risk == :destructive
    assert actions["nextcloud.node.delete"].confirmation == :always

    assert actions["nextcloud.share.create"].confirmation == :always
    assert actions["nextcloud.share.update"].confirmation == :always
    assert actions["nextcloud.share.delete"].risk == :destructive
    assert actions["nextcloud.share.delete"].confirmation == :always

    assert actions["nextcloud.office.launch_token.get"].confirmation == :always
  end

  test "generated modules and catalog packs are available" do
    assert Code.ensure_loaded?(Jido.Connect.Nextcloud.Plugin)

    Enum.each(
      [
        Jido.Connect.Nextcloud.Actions.ListFiles,
        Jido.Connect.Nextcloud.Actions.GetFile,
        Jido.Connect.Nextcloud.Actions.SearchFiles,
        Jido.Connect.Nextcloud.Actions.DownloadFile,
        Jido.Connect.Nextcloud.Actions.CreateFolder,
        Jido.Connect.Nextcloud.Actions.UploadFile,
        Jido.Connect.Nextcloud.Actions.MoveNode,
        Jido.Connect.Nextcloud.Actions.CopyNode,
        Jido.Connect.Nextcloud.Actions.DeleteNode,
        Jido.Connect.Nextcloud.Actions.ListShares,
        Jido.Connect.Nextcloud.Actions.GetShare,
        Jido.Connect.Nextcloud.Actions.CreateShare,
        Jido.Connect.Nextcloud.Actions.UpdateShare,
        Jido.Connect.Nextcloud.Actions.DeleteShare,
        Jido.Connect.Nextcloud.Actions.SearchSharees,
        Jido.Connect.Nextcloud.Actions.GetOfficeCapabilities,
        Jido.Connect.Nextcloud.Actions.GetOfficeLaunchToken
      ],
      &assert(Code.ensure_loaded?(&1))
    )

    assert Enum.map(Nextcloud.catalog_packs(), & &1.id) == [
             :nextcloud_files_readonly,
             :nextcloud_files_write,
             :nextcloud_files_destructive,
             :nextcloud_sharing,
             :nextcloud_office,
             :nextcloud_full
           ]
  end

  test "resolves package scope labels" do
    resolver = Jido.Connect.Nextcloud.ScopeResolver

    assert resolver.required_scopes(%{id: "nextcloud.files.list"}, %{}, %{}) == ["files:read"]
    assert resolver.required_scopes(%{id: "nextcloud.file.upload"}, %{}, %{}) == ["files:write"]
    assert resolver.required_scopes(%{id: "nextcloud.node.delete"}, %{}, %{}) == ["files:write"]
    assert resolver.required_scopes(%{id: "nextcloud.share.create"}, %{}, %{}) == ["files:share"]

    assert resolver.required_scopes(%{id: "nextcloud.office.launch_token.get"}, %{}, %{}) == [
             "office:launch"
           ]
  end
end
