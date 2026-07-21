defmodule Jido.Connect.Nextcloud.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hook for Nextcloud.

  Set `NEXTCLOUD_BASE_URL`, `NEXTCLOUD_LOGIN_NAME`, and
  `NEXTCLOUD_APP_PASSWORD` to run this test against a real Nextcloud instance.
  """

  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.Handlers.Actions.ListFiles

  @moduletag :live_smoke

  unless Enum.all?(
           ["NEXTCLOUD_BASE_URL", "NEXTCLOUD_LOGIN_NAME", "NEXTCLOUD_APP_PASSWORD"],
           &(System.get_env(&1) not in [nil, ""])
         ) do
    @moduletag skip: "Nextcloud live smoke env not set; skipping live smoke tests"
  end

  test "lists root files using live Nextcloud credentials" do
    runtime = %{
      credentials: %{
        base_url: fetch_env("NEXTCLOUD_BASE_URL"),
        login_name: fetch_env("NEXTCLOUD_LOGIN_NAME"),
        app_password: fetch_env("NEXTCLOUD_APP_PASSWORD")
      }
    }

    assert {:ok, %{nodes: nodes}} = ListFiles.run(%{path: "/", depth: "1"}, runtime)
    assert is_list(nodes)
  end

  defp fetch_env(key) do
    System.get_env(key)
  end
end
