defmodule Jido.Connect.MicrosoftOnedrive.DriveTargetTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.MicrosoftOnedrive.DriveTarget

  test "keeps the default OneDrive paths" do
    assert DriveTarget.root(%{}) == {:ok, "/me/drive/root"}
    assert DriveTarget.children(%{}, nil) == {:ok, "/me/drive/root/children"}
    assert DriveTarget.item(%{}, "item-1") == {:ok, "/me/drive/items/item-1"}
    assert DriveTarget.content(%{}, "item-1") == {:ok, "/me/drive/items/item-1/content"}
    assert DriveTarget.delta(%{}, nil) == {:ok, "/me/drive/root/delta"}
  end

  test "targets a SharePoint document library by drive id" do
    input = %{drive_id: "b!library/id"}

    assert DriveTarget.children(input, "folder one") ==
             {:ok, "/drives/b%21library%2Fid/items/folder%20one/children"}

    assert DriveTarget.search(input, "quarterly plan") ==
             {:ok, "/drives/b%21library%2Fid/root/search(q='quarterly+plan')"}

    assert DriveTarget.upload(input, nil, "report one.txt") ==
             {:ok, "/drives/b%21library%2Fid/root:/report%20one.txt:/content"}

    assert DriveTarget.delta(input, "token/value") ==
             {:ok, "/drives/b%21library%2Fid/root/delta(token='token%2Fvalue')"}
  end

  test "rejects invalid drive targets" do
    assert {:error, %Error.ConfigError{key: :drive_id}} =
             DriveTarget.root(%{drive_id: " "})

    assert {:error, %Error.ConfigError{key: :path}} = DriveTarget.item(%{}, "")
    assert {:error, %Error.ConfigError{key: :name}} = DriveTarget.upload(%{}, nil, "")
  end
end
