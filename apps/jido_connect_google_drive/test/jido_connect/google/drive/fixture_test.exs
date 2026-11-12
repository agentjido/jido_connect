defmodule Jido.Connect.Google.Drive.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  test "normalizes common Google Drive file metadata fixture" do
    # files.get of the link-shared text file under the default metadata
    # fields, recorded from the test account.
    payload = LiveSmoke.fixture!(:google_drive, "file_get_shared_link")

    assert {:ok, file} = Normalizer.file(payload)
    assert file.file_id == "1IDOut2ayPl-ubqUf9LlQRbmQV76nve9x"
    assert file.name == "jcl-live shared.txt"
    assert file.mime_type == "text/plain"
    assert file.size == 20
    assert file.parents == ["18wQ5cSzJVV4Hpxmx_okyZi1-Oo1T10wy"]
    assert file.shared? == true
    assert file.modified_time == "2026-10-30T15:29:30.508Z"
    assert file.md5_checksum == "6f7623cb6fccba0a2a58bd709f624c91"
    assert [%{"me" => true, "permissionId" => "permissionId-1"}] = file.owners
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
