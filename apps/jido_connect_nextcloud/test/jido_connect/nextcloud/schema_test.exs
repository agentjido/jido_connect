defmodule Jido.Connect.Nextcloud.SchemaTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Nextcloud.{FileNode, Share, Sharee}

  test "builds file node structs with defaults" do
    node = FileNode.new!(%{path: "/report.txt"})

    assert node.path == "/report.txt"
    assert node.type == :unknown
    assert node.favorite? == false
    assert node.share_types == []
    assert %Zoi.Types.Struct{} = FileNode.schema()
  end

  test "builds share structs with defaults" do
    assert {:ok, share} =
             Share.new(%{share_id: "123", path: "/report.txt", permissions: 31})

    assert share.share_id == "123"
    assert share.permissions == 31
    assert share.metadata == %{}
    assert %Zoi.Types.Struct{} = Share.schema()
  end

  test "builds sharee structs with defaults" do
    sharee = Sharee.new!(%{id: "alice"})

    assert sharee.id == "alice"
    assert sharee.value == %{}
    assert sharee.metadata == %{}
    assert %Zoi.Types.Struct{} = Sharee.schema()
  end
end
