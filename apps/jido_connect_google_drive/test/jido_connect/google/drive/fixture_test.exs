defmodule Jido.Connect.Google.Drive.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes common Google Drive file metadata fixture" do
    payload = fixture!("file_common.json")

    assert {:ok, file} = Normalizer.file(payload)
    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
    assert file.mime_type == "application/pdf"
    assert file.size == 2048
    assert file.parents == ["folder123"]
    assert file.shared? == true
    refute inspect(file) =~ "raw-content-should-not-map"
  end

  test "normalizes edge Google Drive removed-change fixture" do
    payload = fixture!("change_removed_edge.json")

    assert {:ok, change} = Normalizer.change(payload)
    assert change.file_id == "file789"
    assert change.removed? == true
    assert change.file == nil
    assert change.drive_id == "drive123"
  end

  defp fixture!(name) do
    ConnectorContracts.google_fixture!(:google_drive, name, __DIR__)
  end
end
