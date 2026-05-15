defmodule Jido.Connect.Google.SearchConsole.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Normalizer
  alias Jido.Connect.Google.SearchConsole.Site

  test "normalizes a site payload with permission level" do
    payload = %{
      "siteUrl" => "https://example.com/",
      "permissionLevel" => "siteOwner"
    }

    assert {:ok, %Site{} = site} = Normalizer.site(payload)
    assert site.site_url == "https://example.com/"
    assert site.permission_level == "siteOwner"
  end

  test "normalizes a site payload without optional fields" do
    payload = %{
      "siteUrl" => "https://example.com/"
    }

    assert {:ok, %Site{} = site} = Normalizer.site(payload)
    assert site.site_url == "https://example.com/"
  end

  test "returns error for invalid payload" do
    assert {:error, :invalid_site_payload} = Normalizer.site("not a map")
    assert {:error, :invalid_site_payload} = Normalizer.site(nil)
  end

  test "returns error for payload missing siteUrl" do
    assert {:error, _} = Normalizer.site(%{permissionLevel: "siteOwner"})
  end
end
