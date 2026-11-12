defmodule Jido.Connect.Demo.Capture do
  @moduledoc """
  Capture mode for inbound provider deliveries.

  When `<PROVIDER>_CAPTURE_DIR` is set, such as `SLACK_CAPTURE_DIR` or
  `JIRA_CAPTURE_DIR`, the provider's routes write the raw body and headers of
  each request into that directory before handling it. Live smoke tests
  sanitize and replay these files; see `docs/live_smoke_tests.md`.

  Raw captures hold signatures and message content. Keep the directory
  outside the repository.
  """

  @doc "Writes the request to the provider's capture directory when capture mode is on."
  @spec capture(Plug.Conn.t(), String.t()) :: {:ok, Path.t()} | :disabled
  def capture(%Plug.Conn{} = conn, provider) when is_binary(provider) do
    case capture_dir(provider) do
      nil -> :disabled
      dir -> {:ok, write!(conn, provider, dir)}
    end
  end

  @doc "Returns the expanded capture directory of a provider, or `nil` when capture is off."
  @spec capture_dir(String.t()) :: Path.t() | nil
  def capture_dir(provider) when is_binary(provider) do
    case System.get_env("#{String.upcase(provider)}_CAPTURE_DIR") do
      nil -> nil
      "" -> nil
      dir -> Path.expand(dir)
    end
  end

  defp write!(conn, provider, dir) do
    captured_at = System.system_time(:second)
    route = List.last(conn.path_info, "root")
    name = "#{provider}-#{route}-#{captured_at}-#{System.unique_integer([:positive])}.json"
    path = Path.join(dir, name)

    capture = %{
      "provider" => provider,
      "method" => conn.method,
      "path" => conn.request_path,
      "captured_at" => captured_at,
      "headers" => headers(conn.req_headers),
      "body" => conn.assigns[:raw_body] || ""
    }

    File.mkdir_p!(dir)
    File.write!(path, [Jason.encode_to_iodata!(capture, pretty: true), "\n"])
    path
  end

  defp headers(req_headers) do
    Enum.reduce(req_headers, %{}, fn {name, value}, headers ->
      Map.update(headers, name, value, &(&1 <> ", " <> value))
    end)
  end
end
