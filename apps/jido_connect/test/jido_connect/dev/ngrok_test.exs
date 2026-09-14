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
end
