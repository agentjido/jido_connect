defmodule Jido.Connect.Dev.PublicUrlTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Dev.PublicUrl

  test "normalizes absolute public base URLs" do
    assert {:ok, "https://example.test/path"} =
             PublicUrl.resolve(url: "  https://example.test/path/  ")

    assert {:ok, "http://localhost:4000"} = PublicUrl.resolve(url: "http://localhost:4000/")
  end

  test "rejects values that cannot be used as a callback base URL" do
    for url <- [
          "",
          "example.test",
          "/relative/path",
          "ftp://example.test",
          "https://example.test?token=private",
          "https://example.test/#fragment",
          "https://user:secret@example.test",
          "https://exa mple.test"
        ] do
      assert {:error, %Jido.Connect.Error.ConfigError{key: :url}} = PublicUrl.resolve(url: url)
    end
  end
end
