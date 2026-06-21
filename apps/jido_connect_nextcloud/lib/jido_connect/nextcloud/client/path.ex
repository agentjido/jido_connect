defmodule Jido.Connect.Nextcloud.Client.Path do
  @moduledoc false

  @doc "Normalizes a user-facing Nextcloud path to an absolute path."
  def normalize(path)

  def normalize(nil), do: "/"

  def normalize(path) when is_binary(path) do
    path = String.trim(path)

    cond do
      path == "" -> "/"
      String.starts_with?(path, "/") -> collapse_slashes(path)
      true -> collapse_slashes("/" <> path)
    end
  end

  @doc "Encodes a Nextcloud path for URL path segments while preserving separators."
  def encode(path) do
    path
    |> normalize()
    |> String.split("/", trim: true)
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
    |> then(&("/" <> &1))
  end

  @doc "Returns a files DAV URL for a login name and Nextcloud path."
  def files_url(login_name, path) when is_binary(login_name) do
    "/remote.php/dav/files/#{URI.encode(login_name, &URI.char_unreserved?/1)}#{encode(path)}"
  end

  @doc "Returns a full absolute destination URL for WebDAV MOVE/COPY."
  def destination_url(base_url, login_name, path) do
    base_url <> files_url(login_name, path)
  end

  defp collapse_slashes(path), do: Regex.replace(~r{/+}, path, "/")
end
