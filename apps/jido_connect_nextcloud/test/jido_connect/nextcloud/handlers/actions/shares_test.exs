defmodule Jido.Connect.Nextcloud.Handlers.Actions.SharesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.Handlers.Actions.{
    CreateShare,
    DeleteShare,
    GetShare,
    ListShares,
    SearchSharees,
    UpdateShare
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

  test "lists shares" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/ocs/v2.php/apps/files_sharing/api/v1/shares"
      assert Plug.Conn.get_req_header(conn, "ocs-apirequest") == ["true"]

      Req.Test.json(conn, ocs(%{"id" => 1, "path" => "/report.txt", "share_type" => 3}))
    end)

    assert {:ok, %{shares: [%{share_id: "1", path: "/report.txt"}]}} =
             ListShares.run(%{}, runtime())
  end

  test "creates and deletes share" do
    Req.Test.stub(__MODULE__, fn
      %{method: "POST"} = conn ->
        assert conn.request_path == "/ocs/v2.php/apps/files_sharing/api/v1/shares"
        body = URI.decode_query(Req.Test.raw_body(conn))
        assert body["path"] == "/report.txt"
        assert body["shareType"] == "3"
        Req.Test.json(conn, ocs(%{"id" => 2, "path" => "/report.txt", "share_type" => 3}))

      %{method: "DELETE"} = conn ->
        assert conn.request_path == "/ocs/v2.php/apps/files_sharing/api/v1/shares/2"
        Req.Test.json(conn, ocs(%{}))
    end)

    assert {:ok, %{share: %{share_id: "2"}}} =
             CreateShare.run(%{path: "/report.txt", share_type: 3}, runtime())

    assert {:ok, %{deleted: true, share_id: "2"}} =
             DeleteShare.run(%{share_id: "2"}, runtime())
  end

  test "gets and updates share" do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET"} = conn ->
        assert conn.request_path == "/ocs/v2.php/apps/files_sharing/api/v1/shares/2"
        Req.Test.json(conn, ocs(%{"id" => 2, "path" => "/report.txt", "share_type" => 3}))

      %{method: "PUT"} = conn ->
        assert conn.request_path == "/ocs/v2.php/apps/files_sharing/api/v1/shares/2"
        body = URI.decode_query(Req.Test.raw_body(conn))
        assert body["permissions"] == "31"
        assert body["note"] == "team"
        Req.Test.json(conn, ocs(%{"id" => 2, "path" => "/report.txt", "permissions" => 31}))
    end)

    assert {:ok, %{share: %{share_id: "2", path: "/report.txt"}}} =
             GetShare.run(%{share_id: "2"}, runtime())

    assert {:ok, %{share: %{share_id: "2", permissions: 31}}} =
             UpdateShare.run(%{share_id: "2", permissions: 31, note: "team"}, runtime())
  end

  test "searches sharees" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/ocs/v1.php/apps/files_sharing/api/v1/sharees"

      Req.Test.json(
        conn,
        ocs(%{
          "users" => [
            %{"label" => "Alice", "shareType" => 0, "value" => %{"shareWith" => "alice"}}
          ]
        })
      )
    end)

    assert {:ok, %{sharees: [%{id: "alice"}]}} =
             SearchSharees.run(%{search: "ali"}, runtime())
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
