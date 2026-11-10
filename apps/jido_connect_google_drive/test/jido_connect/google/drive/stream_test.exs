defmodule Jido.Connect.Google.Drive.StreamTest do
  use ExUnit.Case, async: true
  alias Jido.Connect.Google.Drive.Client
  alias Jido.Connect.Error.ProviderError

  defp server(responses) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listener)
    parent = self()

    pid =
      spawn_link(fn ->
        Enum.each(responses, fn response ->
          {:ok, socket} = :gen_tcp.accept(listener, 5000)
          {:ok, request} = :gen_tcp.recv(socket, 0, 5000)
          send(parent, {:request, request})
          response.(socket)
          :gen_tcp.close(socket)
        end)

        :gen_tcp.close(listener)
      end)

    {"http://127.0.0.1:#{port}/drive", pid}
  end

  defp reply(status, headers, body) do
    fn socket ->
      :ok =
        :gen_tcp.send(socket, "HTTP/1.1 #{status}\r\nconnection: close\r\n#{headers}\r\n#{body}")
    end
  end

  defp opts(url, limit \\ 100) do
    parent = self()

    [
      max_bytes: limit,
      collector: fn data ->
        send(parent, {:chunk, data})
        :ok
      end,
      req_options: [base_url: url, retry_delay: fn _ -> 0 end, max_retries: 1]
    ]
  end

  test "download and export stream raw chunks with metadata" do
    for {operation, path, params} <- [
          {:stream_download_file, "/drive/v3/files/a%2Fb?alt=media", %{file_id: "a/b"}},
          {:stream_export_file, "/drive/v3/files/a%2Fb/export?mimeType=text%2Fcsv",
           %{file_id: "a/b", mime_type: "text/csv"}}
        ] do
      {url, _} =
        server([
          reply("200 OK", "content-type: application/json\r\ncontent-length: 3\r\n", "[1]")
        ])

      assert {:ok, %{size: 3, status: 200}} =
               apply(Client, operation, [params, "secret", opts(url)])

      assert_receive {:chunk, "[1]"}
      assert_receive {:request, request}
      assert request =~ path
      assert request =~ "authorization: Bearer secret"
    end
  end

  test "declared and actual overflows stop before collecting offending bytes" do
    {url, _} = server([reply("200 OK", "content-length: 6\r\n", "123456")])

    assert {:error, %ProviderError{reason: :limit_exceeded}} =
             Client.stream_download_file(%{file_id: "a"}, "x", opts(url, 4))

    refute_receive {:chunk, _}, 50

    {url, _} =
      server([
        reply("200 OK", "transfer-encoding: chunked\r\n", "3\r\nabc\r\n3\r\ndef\r\n0\r\n\r\n")
      ])

    assert {:error, %ProviderError{reason: :limit_exceeded}} =
             Client.stream_export_file(
               %{file_id: "a", mime_type: "text/plain"},
               "x",
               opts(url, 4)
             )
  end

  test "collector failure is sanitized and stops delivery" do
    {url, _} = server([reply("200 OK", "content-length: 3\r\n", "abc")])
    options = Keyword.put(opts(url), :collector, fn _ -> {:error, "private token"} end)

    assert {:error, %ProviderError{reason: :collector_failed} = error} =
             Client.stream_download_file(%{file_id: "a"}, "x", options)

    refute inspect(error) =~ "private token"
  end

  test "rejects encoded responses" do
    {url, _} = server([reply("200 OK", "content-encoding: gzip\r\ncontent-length: 3\r\n", "abc")])

    assert {:error, %ProviderError{reason: :unsupported_encoding}} =
             Client.stream_download_file(%{file_id: "a"}, "x", opts(url))

    refute_receive {:chunk, _}, 50
  end

  test "retries a transient response before delivering bytes" do
    {url, _} =
      server([
        reply("503 Service Unavailable", "content-length: 0\r\n", ""),
        reply("200 OK", "content-length: 2\r\n", "ok")
      ])

    assert {:ok, %{size: 2}} = Client.stream_download_file(%{file_id: "a"}, "x", opts(url))
    assert_receive {:chunk, "ok"}
    assert_receive {:request, _}
    assert_receive {:request, _}
  end

  test "partial transport failure never retries or duplicates collected data" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listener)
    parent = self()

    spawn(fn ->
      {:ok, socket} = :gen_tcp.accept(listener, 2000)
      {:ok, _} = :gen_tcp.recv(socket, 0, 2000)

      :ok =
        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\ncontent-length: 10\r\nconnection: close\r\n\r\nabc"
        )

      :gen_tcp.close(socket)
      send(parent, {:second_connection, :gen_tcp.accept(listener, 500)})
      :gen_tcp.close(listener)
    end)

    url = "http://127.0.0.1:#{port}/drive"
    assert {:error, _} = Client.stream_download_file(%{file_id: "a"}, "x", opts(url))
    assert_receive {:chunk, "abc"}
    assert_receive {:second_connection, {:error, :timeout}}, 2000
  end

  test "collector blocks further delivery until it returns" do
    parent = self()

    streaming = fn socket ->
      :gen_tcp.send(
        socket,
        "HTTP/1.1 200 OK\r\ntransfer-encoding: chunked\r\nconnection: close\r\n\r\n3\r\none\r\n"
      )

      receive do
        :continue -> :ok
      after
        2000 -> :ok
      end

      :gen_tcp.send(socket, "3\r\ntwo\r\n0\r\n\r\n")
    end

    {url, server_pid} = server([streaming])

    task =
      Task.async(fn ->
        collector = fn data ->
          send(parent, {:received, data})

          receive do
            :continue -> :ok
          end
        end

        Client.stream_download_file(
          %{file_id: "a"},
          "x",
          Keyword.put(opts(url), :collector, collector)
        )
      end)

    assert_receive {:received, "one"}
    send(server_pid, :continue)
    refute_receive {:received, "two"}, 100
    send(task.pid, :continue)
    assert_receive {:received, "two"}
    send(task.pid, :continue)
    assert {:ok, %{size: 6}} = Task.await(task)
  end

  test "cancelling the caller releases the socket" do
    parent = self()

    streaming = fn socket ->
      :gen_tcp.send(
        socket,
        "HTTP/1.1 200 OK\r\ntransfer-encoding: chunked\r\nconnection: close\r\n\r\n3\r\none\r\n"
      )

      send(parent, {:closed, :gen_tcp.recv(socket, 0, 3000)})
    end

    {url, _} = server([streaming])

    pid =
      spawn(fn ->
        collector = fn data ->
          send(parent, {:received, data})

          receive do
            :continue -> :ok
          end
        end

        Client.stream_download_file(
          %{file_id: "a"},
          "x",
          Keyword.put(opts(url), :collector, collector)
        )
      end)

    assert_receive {:received, "one"}
    Process.exit(pid, :kill)
    assert_receive {:closed, {:error, :closed}}, 4000
  end

  test "rejects bytes beyond budget despite inaccurate Drive size metadata" do
    {url, _} =
      server([
        reply(
          "200 OK",
          "transfer-encoding: chunked\r\n",
          "6\r\nabcdef\r\n0\r\n\r\n"
        )
      ])

    assert {:error, %ProviderError{reason: :limit_exceeded}} =
             Client.stream_download_file(
               %{file_id: "a"},
               "x",
               Keyword.put(opts(url, 4), :declared_size, 2)
             )

    refute_receive {:chunk, _}, 50
  end

  test "provider failures are normalized without passing error bodies to the collector" do
    body = ~s({"error":{"message":"not found"}})

    {url, _} =
      server([
        reply(
          "404 Not Found",
          "content-type: application/json\r\ncontent-length: #{byte_size(body)}\r\n",
          body
        )
      ])

    assert {:error, %ProviderError{status: 404}} =
             Client.stream_download_file(%{file_id: "a"}, "x", opts(url))

    refute_receive {:chunk, _}, 50
  end

  test "rejects oversized Drive metadata before making a request" do
    options = [
      max_bytes: 4,
      declared_size: 5,
      collector: fn _ -> flunk("unexpected delivery") end
    ]

    assert {:error, %ProviderError{reason: :limit_exceeded}} =
             Client.stream_download_file(%{file_id: "a"}, "x", options)
  end
end
