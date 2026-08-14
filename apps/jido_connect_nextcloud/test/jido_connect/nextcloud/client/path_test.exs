defmodule Jido.Connect.Nextcloud.Client.PathTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Nextcloud.Client.Path

  test "normalizes and encodes file paths" do
    assert Path.normalize(nil) == "/"
    assert Path.normalize("Documents/report.txt") == "/Documents/report.txt"
    assert Path.normalize("//Documents///report.txt") == "/Documents/report.txt"
    assert Path.encode("/My Files/report 1.txt") == "/My%20Files/report%201.txt"
  end

  test "builds DAV file URLs" do
    assert Path.files_url("alice@example.com", "/My Files/report.txt") ==
             "/remote.php/dav/files/alice%40example.com/My%20Files/report.txt"

    assert Path.destination_url("https://cloud.example.com", "alice", "/Done/report.txt") ==
             "https://cloud.example.com/remote.php/dav/files/alice/Done/report.txt"
  end
end
