defmodule Jido.Connect.Demo.Capture do
  @moduledoc false

  import Bitwise, only: [band: 2]

  @max_files 20
  @max_file_bytes 256 * 1024

  # Call only after Slack accepts the signature. Store just the headers that
  # the fixture sanitizer and verifier need.
  def slack(conn, signature_headers) do
    case System.get_env("SLACK_CAPTURE_DIR") do
      dir when is_binary(dir) and dir != "" -> capture(conn, signature_headers, Path.expand(dir))
      _unset -> :disabled
    end
  end

  defp capture(conn, signature_headers, dir) do
    with {:ok, %File.Stat{type: :directory, mode: mode}} when band(mode, 0o077) == 0 <-
           File.lstat(dir),
         body when byte_size(body) <= @max_file_bytes <- conn.assigns[:raw_body] || "",
         {:ok, data} <- encode(conn, body, signature_headers),
         true <- IO.iodata_length(data) < @max_file_bytes do
      write_slot(dir, [data, "\n"], 1)
    else
      _unavailable -> :skipped
    end
  end

  defp encode(conn, body, signature_headers) do
    content_type = conn |> Plug.Conn.get_req_header("content-type") |> List.first()

    Jason.encode_to_iodata(%{
      "provider" => "slack",
      "method" => conn.method,
      "path" => conn.request_path,
      "captured_at" => System.system_time(:second),
      "headers" => Map.put(signature_headers, "content-type", content_type),
      "body" => body
    })
  end

  defp write_slot(_dir, _data, slot) when slot > @max_files, do: :skipped

  defp write_slot(dir, data, slot) do
    path = Path.join(dir, "slack-#{slot}.json")

    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, file} -> write_capture(file, path, data)
      {:error, :eexist} -> write_slot(dir, data, slot + 1)
      {:error, _reason} -> :skipped
    end
  end

  defp write_capture(file, path, data) do
    written = with :ok <- File.chmod(path, 0o600), do: IO.binwrite(file, data)
    closed = File.close(file)

    if written == :ok and closed == :ok do
      :ok
    else
      File.rm(path)
      :skipped
    end
  end
end
