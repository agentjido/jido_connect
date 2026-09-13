defmodule Jido.Connect.MicrosoftOnedrive.DriveTarget do
  @moduledoc """
  Builds Microsoft Graph paths for the user's default drive or a drive id.

  The optional `drive_id` input lets other Microsoft products reuse the
  OneDrive handlers for SharePoint document libraries.
  """

  alias Jido.Connect.Error

  @spec root(map()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def root(input), do: append(input, ["root"])

  @spec children(map(), term()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def children(input, nil), do: append(input, ["root", "children"])
  def children(input, parent_id), do: append(input, ["items", parent_id, "children"])

  @spec item(map(), term()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def item(input, item_id), do: append(input, ["items", item_id])

  @spec content(map(), term()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def content(input, item_id), do: append(input, ["items", item_id, "content"])

  @spec search(map(), String.t()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def search(input, query) do
    with {:ok, root} <- root(input) do
      {:ok, "#{root}/search(q='#{URI.encode_www_form(query)}')"}
    end
  end

  @spec upload(map(), term(), String.t()) ::
          {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def upload(input, nil, name) do
    with {:ok, base} <- base(input),
         {:ok, name} <- segment(name, :name) do
      {:ok, "#{base}/root:/#{name}:/content"}
    end
  end

  def upload(input, parent_id, name) do
    with {:ok, base} <- base(input),
         {:ok, parent_id} <- segment(parent_id, :parent_id),
         {:ok, name} <- segment(name, :name) do
      {:ok, "#{base}/items/#{parent_id}:/#{name}:/content"}
    end
  end

  @spec delta(map(), term()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def delta(input, nil), do: append(input, ["root", "delta"])

  def delta(input, token) do
    with {:ok, root} <- root(input),
         {:ok, token} <- segment(token, :token) do
      {:ok, "#{root}/delta(token='#{token}')"}
    end
  end

  defp append(input, segments) do
    with {:ok, base} <- base(input),
         {:ok, segments} <- encode_segments(segments) do
      {:ok, Enum.join([base | segments], "/")}
    end
  end

  defp base(input) do
    case Map.get(input, :drive_id) do
      nil ->
        {:ok, "/me/drive"}

      drive_id ->
        with {:ok, drive_id} <- segment(drive_id, :drive_id) do
          {:ok, "/drives/#{drive_id}"}
        end
    end
  end

  defp encode_segments(segments) do
    Enum.reduce_while(segments, {:ok, []}, fn value, {:ok, encoded} ->
      case segment(value, :path) do
        {:ok, value} -> {:cont, {:ok, encoded ++ [value]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp segment(value, key) when is_binary(value) do
    if String.trim(value) == "" or byte_size(value) > max_length(key) do
      {:error, Error.config("Microsoft drive path value is required", key: key)}
    else
      {:ok, URI.encode(value, &URI.char_unreserved?/1)}
    end
  end

  defp segment(_value, key),
    do: {:error, Error.config("Microsoft drive path value is required", key: key)}

  defp max_length(:token), do: 4096
  defp max_length(_key), do: 512
end
