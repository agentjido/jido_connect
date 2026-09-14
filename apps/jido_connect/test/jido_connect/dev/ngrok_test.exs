defmodule Jido.Connect.Dev.NgrokTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Dev.Ngrok

  test "selects only the HTTPS tunnel for the requested local port" do
    tunnels = [
      %{"public_url" => "https://old.example", "config" => %{"addr" => "http://localhost:3000"}},
      %{"public_url" => "http://new.example", "config" => %{"addr" => "localhost:4001"}},
      %{"public_url" => "https://new.example", "config" => %{"addr" => "127.0.0.1:4001"}}
    ]

    assert {:ok, "https://new.example"} = Ngrok.select_public_url(tunnels, 4001)
    assert {:error, :not_found} = Ngrok.select_public_url(tunnels, 4000)
  end

  test "rejects two distinct HTTPS tunnels for the same local port" do
    tunnels = [
      %{"public_url" => "https://one.example", "config" => %{"addr" => "localhost:4001"}},
      %{"public_url" => "https://two.example", "config" => %{"addr" => "localhost:4001"}}
    ]

    assert {:error, :ambiguous} = Ngrok.select_public_url(tunnels, 4001)
  end

  test "does not use a tunnel without a target address" do
    assert {:error, :not_found} =
             Ngrok.select_public_url([%{"public_url" => "https://unknown.example"}], 4001)
  end

  test "reads the selected tunnel from a configured API address" do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_ip, api_port}} = :inet.sockname(listener)

    server =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 2_000)
        {:ok, _request} = :gen_tcp.recv(socket, 0)

        body =
          Jason.encode!(%{
            tunnels: [
              %{public_url: "https://wrong.example", config: %{addr: "localhost:3000"}},
              %{public_url: "https://right.example", config: %{addr: "localhost:4001"}}
            ]
          })

        :ok =
          :gen_tcp.send(socket, [
            "HTTP/1.1 200 OK\r\n",
            "Content-Type: application/json\r\n",
            "Content-Length: #{byte_size(body)}\r\n",
            "Connection: close\r\n\r\n",
            body
          ])

        :gen_tcp.close(socket)
      end)

    assert {:ok, "https://right.example"} =
             Ngrok.public_url(4001, api_url: "http://127.0.0.1:#{api_port}/api/tunnels")

    Task.await(server, 2_000)
    :gen_tcp.close(listener)
  end
end
