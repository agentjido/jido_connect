defmodule Jido.Connect.Google.Drive.FileResolutionTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.Client
  alias Jido.Connect.TestSupport.LiveSmoke

  @shared_file_id "1IDOut2ayPl-ubqUf9LlQRbmQV76nve9x"
  @shortcut_id "1oHPs5PO_okRteaz1Ix_jQvlQLQg1dT-w"
  @doc_id "1uN0Z0Pf8rvP1ewCITuP9mS9fLdlyweoJ1zihNsneFLk"
  @resource_key "0-AbCdEf_GhIjKl12345"
  @header "x-goog-drive-resource-keys"

  # File ID and resource key sent by the live test that recorded the 404.
  @missing_file_id "1JclLiveSmokeMissingFile000000000"
  @live_resource_key "0-JclLiveSmokeResourceKey"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_drive,
      :google_drive_api_base_url,
      "https://drive.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_drive, :google_drive_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  for operation <- [:get, :export, :download] do
    test "#{operation} sends <fileId>/<resourceKey> in the resource key header, not in the query" do
      %{client: client, input: input, path: path, fixture: fixture} =
        operation(unquote(operation))

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == path
        assert Plug.Conn.get_req_header(conn, @header) == ["#{input.file_id}/#{@resource_key}"]
        refute conn.query_string =~ @resource_key
        replay(conn, fixture)
      end)

      assert {:ok, _result} =
               apply(Client, client, [Map.put(input, :resource_key, @resource_key), "token"])
    end

    test "#{operation} sends no resource key header without a resource key" do
      %{client: client, input: input, path: path, fixture: fixture} =
        operation(unquote(operation))

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == path
        assert Plug.Conn.get_req_header(conn, @header) == []
        replay(conn, fixture)
      end)

      assert {:ok, _result} = apply(Client, client, [input, "token"])
    end

    # A host's empty optional form field arrives as "".
    test "#{operation} treats an empty resource key as absent" do
      %{client: client, input: input, path: path, fixture: fixture} =
        operation(unquote(operation))

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == path
        assert Plug.Conn.get_req_header(conn, @header) == []
        replay(conn, fixture)
      end)

      assert {:ok, _result} = apply(Client, client, [Map.put(input, :resource_key, ""), "token"])
    end

    # No Req.Test expectation: a request would fail the test.
    test "#{operation} rejects a resource key that does not form one header pair, before any request" do
      %{client: client, input: input} = operation(unquote(operation))

      for key <- [
            "0-LeakCheck,#{@doc_id}/0-Other",
            "0-LeakCheck/0-Other",
            "0-LeakCheck\r\nx-injected: true",
            "  "
          ] do
        assert {:error,
                %Connect.Error.ValidationError{
                  reason: :invalid_resource_key,
                  subject: :resource_key
                } = error} = apply(Client, client, [Map.put(input, :resource_key, key), "token"])

        refute inspect(error) =~ "0-LeakCheck"
      end
    end

    test "#{operation} rejects a file ID that does not form one header pair with the resource key" do
      %{client: client, input: input} = operation(unquote(operation))

      input =
        Map.merge(input, %{file_id: "#{input.file_id},#{@doc_id}", resource_key: @resource_key})

      assert {:error,
              %Connect.Error.ValidationError{reason: :invalid_file_id, subject: :file_id} = error} =
               apply(Client, client, [input, "token"])

      refute inspect(error) =~ @resource_key
    end

    test "#{operation} action carries resource_key from its input to the wire" do
      %{action: action, input: input, fixture: fixture} = operation(unquote(operation))

      Req.Test.expect(__MODULE__, fn conn ->
        assert Plug.Conn.get_req_header(conn, @header) == ["#{input.file_id}/#{@resource_key}"]
        refute conn.query_string =~ @resource_key
        replay(conn, fixture)
      end)

      assert {:ok, _result} = invoke(action, Map.put(input, :resource_key, @resource_key))
    end
  end

  test "file get returns a shortcut's target fields without a second request" do
    Req.Test.expect(__MODULE__, 1, fn conn ->
      assert conn.request_path == "/v3/files/#{@shortcut_id}"
      replay(conn, "file_get_shortcut")
    end)

    assert {:ok,
            %{
              file: %{
                file_id: @shortcut_id,
                mime_type: "application/vnd.google-apps.shortcut",
                shortcut_target_id: @shared_file_id,
                shortcut_target_mime_type: "text/plain",
                shortcut_target_resource_key: nil
              }
            }} = invoke("google.drive.file.get", %{file_id: @shortcut_id})
  end

  test "provider error details never contain the resource key" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(LiveSmoke.fixture!(:google_drive, "file_get_not_found"))
    end)

    assert {:error, %Connect.Error.ProviderError{provider: :google, status: 404} = error} =
             invoke("google.drive.file.get", %{
               file_id: @missing_file_id,
               resource_key: @live_resource_key
             })

    refute inspect(error) =~ @live_resource_key
    refute inspect(Connect.Error.to_map(error)) =~ @live_resource_key
  end

  defp operation(:get) do
    %{
      client: :get_file,
      action: "google.drive.file.get",
      input: %{file_id: @shared_file_id},
      path: "/v3/files/#{@shared_file_id}",
      fixture: "file_get_shared_link"
    }
  end

  defp operation(:export) do
    %{
      client: :export_file,
      action: "google.drive.file.export",
      input: %{file_id: @doc_id, mime_type: "text/plain"},
      path: "/v3/files/#{@doc_id}/export",
      fixture: "file_export"
    }
  end

  defp operation(:download) do
    %{
      client: :download_file,
      action: "google.drive.file.download",
      input: %{file_id: @shared_file_id},
      path: "/v3/files/#{@shared_file_id}",
      fixture: "file_download"
    }
  end

  # The recorded metadata responses are JSON; the export and download
  # responses were recorded with `content-type: text/plain`.
  defp replay(conn, "file_get_" <> _rest = fixture),
    do: Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, fixture))

  defp replay(conn, fixture) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain", nil)
    |> Plug.Conn.resp(200, LiveSmoke.fixture!(:google_drive, fixture))
  end

  defp invoke(action_id, input) do
    scopes = ["https://www.googleapis.com/auth/drive.readonly"]

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token"},
        scopes: scopes
      })

    Connect.invoke(Drive.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end
end
