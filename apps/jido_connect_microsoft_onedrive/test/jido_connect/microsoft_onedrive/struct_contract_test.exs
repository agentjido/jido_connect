defmodule Jido.Connect.MicrosoftOnedrive.StructContractTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOnedrive.{
    DeltaToken,
    Download,
    Drive,
    DriveItem,
    FileFacet,
    Folder,
    Permission,
    SharingLink,
    Thumbnail
  }

  test "public structs expose schemas and strict constructors" do
    contracts = [
      {DeltaToken, %{}},
      {Download, %{}},
      {Drive, %{drive_id: "drive-1"}},
      {DriveItem, %{item_id: "item-1", etag: "\"item-1,2\""}},
      {FileFacet, %{}},
      {Folder, %{}},
      {Permission, %{permission_id: "permission-1"}},
      {SharingLink, %{}},
      {Thumbnail, %{}}
    ]

    Enum.each(contracts, fn {module, attrs} ->
      assert module.schema()
      assert %{__struct__: ^module} = module.new!(attrs)
    end)
  end
end
