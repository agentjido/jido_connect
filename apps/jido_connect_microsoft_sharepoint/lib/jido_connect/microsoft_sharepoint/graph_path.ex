defmodule Jido.Connect.MicrosoftSharepoint.GraphPath do
  @moduledoc false

  alias Jido.Connect.Error

  @spec site(String.t()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def site(site_id), do: resource_path(["sites", site_id])

  @spec site_by_path(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def site_by_path(hostname, relative_path)
      when is_binary(hostname) and is_binary(relative_path) do
    if Regex.match?(~r/\A[A-Za-z0-9.-]+\z/, hostname) do
      path =
        relative_path
        |> String.trim()
        |> String.trim("/")
        |> String.split("/", trim: true)
        |> Enum.map_join("/", &segment/1)

      if path == "" do
        {:error, config_error(:relative_path, "SharePoint relative_path is required")}
      else
        {:ok, "/sites/#{hostname}:/#{path}"}
      end
    else
      {:error, config_error(:hostname, "SharePoint hostname is invalid")}
    end
  end

  def site_by_path(_hostname, _relative_path),
    do: {:error, config_error(:relative_path, "SharePoint site path is invalid")}

  @spec resource_path([term()]) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def resource_path(segments) when is_list(segments) do
    if Enum.all?(segments, &valid_segment?/1) do
      {:ok, "/" <> Enum.map_join(segments, "/", &segment/1)}
    else
      {:error, config_error(:resource_id, "SharePoint resource id is invalid")}
    end
  end

  defp valid_segment?(value), do: is_binary(value) and String.trim(value) != ""
  defp segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp config_error(key, message), do: Error.config(message, key: key)
end
