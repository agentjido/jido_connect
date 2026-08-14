defmodule Jido.Connect.Nextcloud.LoginFlowTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.LoginFlow

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_nextcloud, :nextcloud_login_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_nextcloud, :nextcloud_login_req_options)
    end)
  end

  test "initializes login flow v2" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/index.php/login/v2"

      Req.Test.json(conn, %{
        "login" => "https://cloud.example.com/login/v2/flow/abc",
        "poll" => %{"token" => "token", "endpoint" => "https://cloud.example.com/login/v2/poll"}
      })
    end)

    assert {:ok, %{login: login, poll: %{"token" => "token"}}} =
             LoginFlow.init("https://cloud.example.com/")

    assert login == "https://cloud.example.com/login/v2/flow/abc"
  end

  test "polls successful login flow result" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/login/v2/poll"
      assert URI.decode_query(Req.Test.raw_body(conn))["token"] == "token"

      Req.Test.json(conn, %{
        "server" => "https://cloud.example.com/",
        "loginName" => "alice",
        "appPassword" => "generated-app-password"
      })
    end)

    assert {:ok,
            %{
              base_url: "https://cloud.example.com",
              login_name: "alice",
              app_password: "generated-app-password"
            }} = LoginFlow.poll("https://cloud.example.com/login/v2/poll", "token")
  end

  test "returns pending while login flow has not completed" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      Plug.Conn.resp(conn, 404, "")
    end)

    assert {:error, error} = LoginFlow.poll("https://cloud.example.com/login/v2/poll", "token")
    assert error.reason == :pending
  end
end
