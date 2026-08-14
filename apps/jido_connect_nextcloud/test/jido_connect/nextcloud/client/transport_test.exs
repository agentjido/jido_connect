defmodule Jido.Connect.Nextcloud.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.Client.{Credentials, Transport}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_nextcloud, :nextcloud_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_nextcloud, :nextcloud_req_options)
    end)
  end

  test "executes custom WebDAV methods" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "MKCOL"
      assert conn.request_path == "/remote.php/dav/files/alice/New"
      assert ["Basic " <> _] = Plug.Conn.get_req_header(conn, "authorization")
      Plug.Conn.resp(conn, 201, "")
    end)

    request = Transport.request(credentials())

    assert {:ok, %{status: 201}} =
             Transport.request(request, :mkcol, url: "/remote.php/dav/files/alice/New")
  end

  test "normalizes provider error responses" do
    assert {:error, error} =
             Transport.handle_error_response(
               {:ok, %{status: 404, body: %{"message" => "Missing"}}},
               message: "Nextcloud failed"
             )

    assert error.provider == :nextcloud
    assert error.reason == :not_found
    assert error.status == 404
    assert error.details.message == "Missing"
  end

  test "maps common HTTP status codes to provider reasons" do
    [
      {401, :unauthorized},
      {403, :forbidden},
      {409, :conflict},
      {423, :locked},
      {429, :rate_limited},
      {500, :server_error},
      {400, :http_error}
    ]
    |> Enum.each(fn {status, reason} ->
      assert {:error, error} =
               Transport.handle_error_response({:ok, %{status: status, body: "failed"}})

      assert error.reason == reason
      assert error.details.message == "failed"
    end)
  end

  test "extracts OCS and atom-key error messages" do
    assert {:error, ocs_error} =
             Transport.handle_error_response(
               {:ok,
                %{
                  status: 400,
                  body: %{"ocs" => %{"meta" => %{"message" => "OCS failed"}}}
                }}
             )

    assert ocs_error.details.message == "OCS failed"

    assert {:error, atom_error} =
             Transport.handle_error_response({:ok, %{status: 400, body: %{message: "Bad"}}})

    assert atom_error.details.message == "Bad"
  end

  test "builds invalid success response" do
    assert {:error, error} = Transport.invalid_success_response("Bad body", %{bad: true})

    assert error.provider == :nextcloud
    assert error.reason == :invalid_response
    assert error.details.body_summary.keys == [:bad]
  end

  defp credentials do
    {:ok, credentials} =
      Credentials.from_credentials(%{
        base_url: "https://cloud.example.com",
        login_name: "alice",
        app_password: "secret"
      })

    credentials
  end
end
