defmodule Jido.Connect.Nextcloud.Handlers.Actions.OfficeTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.Handlers.Actions.{
    GetOfficeCapabilities,
    GetOfficeLaunchToken
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_nextcloud, :nextcloud_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_nextcloud, :nextcloud_req_options)
    end)
  end

  test "gets office capabilities from nested Nextcloud capabilities payload" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/ocs/v2.php/cloud/capabilities"

      Req.Test.json(
        conn,
        ocs(%{
          "capabilities" => %{
            "richdocuments" => %{"version" => "11.0.0", "external_apps" => true}
          }
        })
      )
    end)

    assert {:ok, %{office: %{available?: true, supports_external_apps?: true}}} =
             GetOfficeCapabilities.run(%{}, runtime())
  end

  test "gets office launch metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/index.php/apps/richdocuments/wopi/extapp/data/42"
      assert conn.query_params["app_id"] == "app"
      assert conn.query_params["app_secret"] == "secret"

      Req.Test.json(
        conn,
        ocs(%{
          "access_token" => "token",
          "urlsrc" => "https://office.example.com/browser/abc"
        })
      )
    end)

    assert {:ok, %{launch: %{"access_token" => "token"}}} =
             GetOfficeLaunchToken.run(
               %{file_id: "42", app_id: "app", app_secret: "secret"},
               runtime()
             )
  end

  defp runtime do
    %{
      credentials: %{
        base_url: "https://cloud.example.com",
        login_name: "alice",
        app_password: "secret"
      }
    }
  end

  defp ocs(data) do
    %{"ocs" => %{"meta" => %{"status" => "ok", "statuscode" => 100}, "data" => data}}
  end
end
