defmodule Jido.Connect.Google.Drive.FileUploadTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.TestSupport.LiveSmoke

  # The multipart limit and the upload folder of the recorded live upload.
  @limit 5_242_880
  @folder_id "115ptv8wqbkEFu-3aaOqGiRda0uPYH4I1"
  @media_header "Content-Type: application/octet-stream\r\n\r\n"
  @marker "jcl-upload-marker "

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

  test "accepts exactly 5,242,880 bytes as content and sends them unchanged" do
    content = limit_content()
    expect_upload(content)

    assert {:ok, %{file: file}} = upload(%{content: content})
    assert_recorded_upload(file, content)
  end

  test "accepts exactly 5,242,880 decoded bytes as content_base64 and sends the decoded bytes" do
    content = limit_content()
    expect_upload(content)

    assert {:ok, %{file: file}} = upload(%{content_base64: Base.encode64(content)})
    assert_recorded_upload(file, content)
  end

  # No Req.Test expectation: a request would fail the test.
  test "rejects one byte more, as content or content_base64, before any request" do
    content = :binary.copy(@marker, div(@limit, byte_size(@marker)) + 1)
    one_more = binary_part(content, 0, @limit + 1)

    for input <- [%{content: one_more}, %{content_base64: Base.encode64(one_more)}] do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :upload_too_large,
                details: %{actual_bytes: 5_242_881, max_bytes: @limit}
              } = error} = upload(input)

      assert error.message ==
               "Google Drive file uploads are limited to 5,242,880 bytes (5 MiB); " <>
                 "larger files are not supported"

      refute inspect(error) =~ @marker
      refute inspect(Connect.Error.to_map(error)) =~ @marker
    end
  end

  # The live check of 2026-11-06 sent these types in both multipart parts:
  # Drive answered 400 for Docs, Sheets, Apps Script JSON and an upper-case
  # Docs type, and turned the folder type into an empty folder. No Req.Test
  # expectation: a request would fail the test.
  test "rejects Google Workspace MIME types before any request" do
    for mime_type <- [
          "application/vnd.google-apps.document",
          "application/vnd.google-apps.spreadsheet",
          "application/vnd.google-apps.script+json",
          "application/vnd.google-apps.folder",
          "Application/VND.Google-Apps.Document"
        ] do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :unsupported_mime_type,
                subject: :mime_type
              } = error} = upload(%{content: "jcl upload", mime_type: mime_type})

      assert error.message ==
               "Google Drive file uploads do not accept Google Workspace MIME types " <>
                 "(application/vnd.google-apps.*); pass the media type of the bytes"
    end
  end

  test "accepts other vendor MIME types, such as an Office document" do
    mime_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "\r\nContent-Type: #{mime_type}\r\n\r\njcl upload\r\n"

      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "file_upload"))
    end)

    assert {:ok, %{file: _file}} = upload(%{content: "jcl upload", mime_type: mime_type})
  end

  # 5,242,896 bytes: the encoding is longer than any encoding of 5,242,880 bytes.
  test "rejects content_base64 too long for the limit before decoding it" do
    content_base64 = Base.encode64(:binary.copy(@marker, div(@limit, byte_size(@marker)) + 1))

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :upload_too_large,
              subject: :content_base64,
              details: %{max_decoded_bytes: @limit}
            } = error} = upload(%{content_base64: content_base64})

    assert error.message =~ "5,242,880 bytes"
    refute inspect(error) =~ binary_part(content_base64, 0, 24)
  end

  # The request carries no pre-generated file ID, so Drive may have created the
  # file, and a repeat would create a second one.
  test "reports a timed-out upload as an unknown outcome that must not be retried" do
    test_pid = self()

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, :upload_attempt)
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error,
            %Connect.Error.ProviderError{
              delivery: :sent_outcome_unknown,
              mutation?: true,
              provider_idempotency?: false
            } = error} = upload(%{content: "jcl upload"})

    assert Connect.Error.retry_guidance(error) == :do_not_retry
    assert_receive :upload_attempt
    refute_receive :upload_attempt, 50
  end

  # Every byte value, 20,480 times: the content of the recorded live upload.
  defp limit_content, do: :binary.copy(:binary.list_to_bin(Enum.to_list(0..255)), 20_480)

  defp expect_upload(content) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/upload/drive/v3/files"
      assert conn.query_params["uploadType"] == "multipart"

      ["multipart/related; boundary=" <> boundary] =
        Plug.Conn.get_req_header(conn, "content-type")

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert [metadata, media] = String.split(body, @media_header, parts: 2)
      assert metadata =~ ~s("parents":["#{@folder_id}"])

      # Compared by digest, so a mismatch does not print 5 MiB.
      assert digest(:sha256, media) == digest(:sha256, content <> "\r\n--#{boundary}--\r\n")

      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "file_upload"))
    end)
  end

  # Drive computed the recorded md5Checksum from the bytes of the live upload.
  defp assert_recorded_upload(file, content) do
    assert file.parents == [@folder_id]
    assert file.size == @limit
    assert file.md5_checksum == digest(:md5, content)
  end

  defp digest(algorithm, bytes),
    do: algorithm |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  defp upload(content_input) do
    scopes = ["https://www.googleapis.com/auth/drive.file"]

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

    input =
      Map.merge(
        %{
          name: "jcl-live upload.bin",
          mime_type: "application/octet-stream",
          parents: [@folder_id]
        },
        content_input
      )

    Connect.invoke(Drive.integration(), "google.drive.file.upload", input,
      context: context,
      credential_lease: lease
    )
  end
end
