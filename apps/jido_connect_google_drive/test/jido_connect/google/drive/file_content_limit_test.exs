defmodule Jido.Connect.Google.Drive.FileContentLimitTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.Client
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  # The live test recorded the plain-text export of the tabbed document, 77
  # bytes, and the size read and download of the 20-byte link-shared file.
  @export_bytes 77
  @download_bytes 20

  @resource_key "0-AbCdEf_GhIjKl12345"
  @resource_key_header "x-goog-drive-resource-keys"

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

  describe "google.drive.file.export with max_bytes" do
    test "returns the recorded export unchanged when it is exactly max_bytes long" do
      recorded = recording!("file_export_max_bytes")
      file_id = export_file_id(recorded)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/v3/files/#{file_id}/export"
        assert conn.query_params == %{"mimeType" => "text/plain"}

        replay(conn, recorded)
      end)

      assert {:ok, %{file_content: file_content}} =
               invoke("google.drive.file.export", %{
                 file_id: file_id,
                 mime_type: "text/plain",
                 max_bytes: @export_bytes
               })

      assert file_content == %{
               file_id: file_id,
               mime_type: "text/plain",
               size: @export_bytes,
               content: recorded["body"],
               encoding: "utf-8",
               binary: false
             }
    end

    test "fails without content when the export is one byte longer than max_bytes" do
      recorded = recording!("file_export_max_bytes")

      Req.Test.expect(__MODULE__, &replay(&1, recorded))

      assert {:error, %Error.ProviderError{} = error} =
               invoke("google.drive.file.export", %{
                 file_id: export_file_id(recorded),
                 mime_type: "text/plain",
                 max_bytes: @export_bytes - 1
               })

      assert %{provider: :google, reason: :limit_exceeded} = error
      assert error.details.max_bytes == @export_bytes - 1
      refute Error.retryable?(error)
      assert Error.retry_guidance(error) == :do_not_retry
      refute_content(error, recorded["body"])
    end

    # Drive declares no size for an export. Sent in chunks without
    # `content-length`, the export is only known to be too long once its bytes
    # are counted.
    test "counts an export without content-length while it arrives" do
      recorded = recording!("file_export_max_bytes")
      body = recorded["body"]
      input = %{file_id: export_file_id(recorded), mime_type: "text/plain"}

      Req.Test.expect(__MODULE__, 2, &replay_chunked(&1, recorded, body))

      assert {:ok, %{file_content: %{size: @export_bytes, content: ^body}}} =
               invoke("google.drive.file.export", Map.put(input, :max_bytes, @export_bytes))

      assert {:error, %Error.ProviderError{reason: :limit_exceeded} = error} =
               invoke("google.drive.file.export", Map.put(input, :max_bytes, @export_bytes - 1))

      refute_content(error, body)
    end
  end

  describe "google.drive.file.download with max_bytes" do
    test "fails on Drive's declared size without requesting the content" do
      size_read = recording!("file_download_max_bytes")
      file_id = download_file_id(size_read)
      assert size_read["body"]["size"] == "#{@download_bytes}"

      # One expectation: a content request would find none left.
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/v3/files/#{file_id}"
        refute Map.has_key?(conn.query_params, "alt")

        replay(conn, size_read)
      end)

      assert {:error, %Error.ProviderError{reason: :limit_exceeded} = error} =
               invoke("google.drive.file.download", %{
                 file_id: file_id,
                 max_bytes: @download_bytes - 1
               })

      assert error.details.max_bytes == @download_bytes - 1
      refute Error.retryable?(error)
    end

    test "reads the size first and returns the recorded download unchanged at exactly max_bytes" do
      size_read = recording!("file_download_max_bytes")
      download = recording!("file_download_max_bytes.2")
      file_id = download_file_id(size_read)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/v3/files/#{file_id}"
        assert conn.query_params == %{"fields" => "size,mimeType", "supportsAllDrives" => "false"}

        replay(conn, size_read)
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/v3/files/#{file_id}"
        assert conn.query_params == %{"alt" => "media", "supportsAllDrives" => "false"}

        replay(conn, download)
      end)

      assert {:ok, %{file_content: file_content}} =
               invoke("google.drive.file.download", %{
                 file_id: file_id,
                 max_bytes: @download_bytes
               })

      assert file_content == %{
               file_id: file_id,
               mime_type: "text/plain",
               size: @download_bytes,
               content: download["body"],
               encoding: "utf-8",
               binary: false
             }
    end

    # Without the resource key of a link-shared file, or without
    # supportsAllDrives for a file in a shared drive, Drive answers the size
    # read with 404, so it needs both just like the download.
    test "sends the resource key and supports_all_drives on the size read as on the download" do
      size_read = recording!("file_download_max_bytes")
      download = recording!("file_download_max_bytes.2")
      file_id = download_file_id(size_read)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/v3/files/#{file_id}"
        assert conn.query_params == %{"fields" => "size,mimeType", "supportsAllDrives" => "true"}

        assert Plug.Conn.get_req_header(conn, @resource_key_header) == [
                 "#{file_id}/#{@resource_key}"
               ]

        replay(conn, size_read)
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_params == %{"alt" => "media", "supportsAllDrives" => "true"}

        assert Plug.Conn.get_req_header(conn, @resource_key_header) == [
                 "#{file_id}/#{@resource_key}"
               ]

        replay(conn, download)
      end)

      assert {:ok, %{file_content: %{file_id: ^file_id, size: @download_bytes}}} =
               invoke("google.drive.file.download", %{
                 file_id: file_id,
                 resource_key: @resource_key,
                 supports_all_drives: true,
                 max_bytes: @download_bytes
               })
    end

    # Drive leaves `size` out for some files. Such a file, and one whose
    # `size` is not a whole number, goes on to the content request, where
    # the count applies.
    test "a size read without a usable size goes on to the download" do
      size_read = recording!("file_download_max_bytes")
      download = recording!("file_download_max_bytes.2")
      file_id = download_file_id(size_read)

      for metadata <- [
            Map.delete(size_read["body"], "size"),
            Map.put(size_read["body"], "size", "unknown")
          ] do
        Req.Test.expect(__MODULE__, &replay(&1, %{size_read | "body" => metadata}))
        Req.Test.expect(__MODULE__, &replay(&1, download))

        assert {:ok, %{file_content: %{file_id: ^file_id, size: @download_bytes}}} =
                 invoke("google.drive.file.download", %{
                   file_id: file_id,
                   max_bytes: @download_bytes
                 })
      end
    end

    # The recorded size read declares 20 bytes; the content sent is the
    # recorded body and one byte more, in chunks without `content-length`.
    test "counts the bytes when Drive sends more than it declared" do
      size_read = recording!("file_download_max_bytes")
      download = recording!("file_download_max_bytes.2")
      body = download["body"] <> "!"

      Req.Test.expect(__MODULE__, &replay(&1, size_read))
      Req.Test.expect(__MODULE__, &replay_chunked(&1, download, body))

      assert {:error, %Error.ProviderError{reason: :limit_exceeded} = error} =
               invoke("google.drive.file.download", %{
                 file_id: download_file_id(size_read),
                 max_bytes: @download_bytes
               })

      refute_content(error, body)
    end

    # Drive declares 1024 bytes for the tabbed Google Doc, which has no bytes
    # to download, and refuses its download with 403.
    test "a Google Doc's declared size does not stop the download" do
      size_read = recording!("file_download_max_bytes_google_doc")
      refusal = recording!("file_download_max_bytes_google_doc.2")
      assert size_read["body"]["size"] == "1024"

      Req.Test.expect(__MODULE__, &replay(&1, size_read))
      Req.Test.expect(__MODULE__, &replay(&1, refusal))

      assert {:error, %Error.ProviderError{status: 403, reason: :http_error} = error} =
               invoke("google.drive.file.download", %{
                 file_id: download_file_id(size_read),
                 max_bytes: 1
               })

      assert error.details.message ==
               "Only files with binary content can be downloaded. Use Export with Docs Editors files."
    end
  end

  describe "invalid max_bytes" do
    test "the actions reject a negative max_bytes before any request" do
      inputs = [
        {"google.drive.file.export", %{file_id: "file123", mime_type: "text/plain"}},
        {"google.drive.file.download", %{file_id: "file123"}}
      ]

      for {action_id, input} <- inputs do
        assert {:error, %Error.ValidationError{}} =
                 invoke(action_id, Map.put(input, :max_bytes, -1))
      end
    end

    test "the client rejects a max_bytes that is not a non-negative integer before any request" do
      for max_bytes <- [-1, 1.5, "10"],
          call <- [
            &Client.export_file(
              %{file_id: "file123", mime_type: "text/plain", max_bytes: &1},
              "t"
            ),
            &Client.download_file(%{file_id: "file123", max_bytes: &1}, "t")
          ] do
        assert {:error, %Error.ValidationError{reason: :invalid_max_bytes, subject: :max_bytes}} =
                 call.(max_bytes)
      end
    end
  end

  describe "reading with max_bytes" do
    # Error bodies do not count against max_bytes, so Google's message stays,
    # from the export and from the size read before a download.
    test "a missing file fails with Google's message under max_bytes" do
      for {name, call} <- [
            {"file_download_not_found",
             &Client.export_file(%{file_id: &1, mime_type: "text/plain", max_bytes: 10}, "t")},
            {"file_get_not_found", &Client.download_file(%{file_id: &1, max_bytes: 10}, "t")}
          ] do
        recorded = recording!(name)
        %{"error" => %{"message" => "File not found: " <> _id = message}} = recorded["body"]

        Req.Test.expect(__MODULE__, &replay(&1, recorded))

        assert {:error, %Error.ProviderError{status: 404, reason: :http_error} = error} =
                 call.(download_file_id(recorded))

        assert error.details.message == message
      end
    end

    # A local server sends the first 16 bytes of a chunked body and then
    # waits. The client closes the connection at the limit instead of
    # waiting for the rest.
    test "stops reading from the connection at the limit" do
      serve_and_wait(
        "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\ntransfer-encoding: chunked\r\n\r\n" <>
          "10\r\n0123456789abcdef\r\n"
      )

      assert {:error, %Error.ProviderError{reason: :limit_exceeded}} =
               Client.export_file(
                 %{file_id: "file123", mime_type: "text/plain", max_bytes: 10},
                 "token"
               )

      assert_receive {:server, {:error, :closed}}, 5_000
    end

    # Drive sent the recorded export with `content-length: 77`. Here the
    # server sends the first 16 of 77 declared bytes and then waits: the
    # client stops at that chunk, although the chunk alone is within the
    # limit, instead of reading up to max_bytes.
    test "stops at the first chunk when content-length declares more than max_bytes" do
      serve_and_wait(
        "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\ncontent-length: #{@export_bytes}\r\n\r\n" <>
          "0123456789abcdef"
      )

      assert {:error, %Error.ProviderError{reason: :limit_exceeded} = error} =
               Client.export_file(
                 %{file_id: "file123", mime_type: "text/plain", max_bytes: @export_bytes - 1},
                 "token"
               )

      assert error.details.max_bytes == @export_bytes - 1
      assert_receive {:server, {:error, :closed}}, 5_000
    end
  end

  # Serves one request on a local port: sends `response` and then waits up to
  # five seconds for more from the client, which it reports to the test as
  # `{:server, result}`. Drive's base URL points to that port, without retry.
  defp serve_and_wait(response) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listener)
    test = self()

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listener, 5_000)
      {:ok, _request} = :gen_tcp.recv(socket, 0, 5_000)
      :ok = :gen_tcp.send(socket, response)
      send(test, {:server, :gen_tcp.recv(socket, 0, 5_000)})
    end)

    Application.put_env(
      :jido_connect_google_drive,
      :google_drive_api_base_url,
      "http://127.0.0.1:#{port}/drive"
    )

    Application.put_env(:jido_connect_google, :google_req_options, retry: false)
  end

  # The whole recording: the replay needs its status and headers.
  defp recording!(name) do
    ConnectorContracts.google_fixture!(:google_drive, "recorded/#{name}.json", __DIR__)
  end

  defp export_file_id(recorded) do
    "/drive/v3/files/" <> rest = recorded["request"]["path"]
    String.replace_suffix(rest, "/export", "")
  end

  defp download_file_id(recorded) do
    "/drive/v3/files/" <> file_id = recorded["request"]["path"]
    file_id
  end

  # Answers with the recorded status, headers and body, a decoded JSON body
  # encoded again. Unlike the other replays it keeps a recorded
  # `content-length`, which the limit reads.
  defp replay(conn, recorded) do
    body =
      case recorded["body"] do
        body when is_binary(body) -> body
        body -> Jason.encode!(body)
      end

    conn
    |> Plug.Conn.merge_resp_headers(headers(recorded, ["transfer-encoding", "x-goog-hash"]))
    |> Plug.Conn.resp(recorded["status"], body)
  end

  # Answers with the recorded status and headers around `body`, without
  # `content-length` and in chunks of 16 bytes.
  defp replay_chunked(conn, recorded, body) do
    conn =
      conn
      |> Plug.Conn.merge_resp_headers(headers(recorded, ["content-length", "x-goog-hash"]))
      |> Plug.Conn.send_chunked(recorded["status"])

    body
    |> chunks()
    |> Enum.reduce(conn, fn chunk, conn ->
      {:ok, conn} = Plug.Conn.chunk(conn, chunk)
      conn
    end)
  end

  defp headers(recorded, dropped) do
    for {name, values} <- Map.drop(recorded["headers"], dropped),
        do: {name, Enum.join(values, ", ")}
  end

  defp chunks(<<chunk::binary-size(16), rest::binary>>), do: [chunk | chunks(rest)]
  defp chunks(""), do: []
  defp chunks(rest), do: [rest]

  # No part of the file's text, here its first marker line, reaches the error
  # or its public map.
  defp refute_content(error, body) do
    first_line = body |> String.trim_leading("﻿") |> String.split(["\r\n", "\n"]) |> hd()
    assert byte_size(first_line) > 0
    refute inspect(error) =~ first_line
    refute inspect(Error.to_map(error)) =~ first_line
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
