defmodule Jido.Connect.MicrosoftSharepoint.DeltaCursor do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Microsoft.Transport

  @spec validate(term(), String.t()) ::
          {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def validate(cursor, resource_path)
      when is_binary(cursor) and byte_size(cursor) <= 8192 and is_binary(resource_path) do
    base = URI.parse(Transport.base_url())
    uri = URI.parse(cursor)
    expected_path = String.trim_trailing(base.path || "", "/") <> resource_path

    if same_origin?(uri, base) and same_path?(uri.path, expected_path) and present?(uri.query) and
         is_nil(uri.userinfo) and is_nil(uri.fragment) do
      {:ok, cursor}
    else
      invalid_cursor()
    end
  end

  def validate(_cursor, _resource_path), do: invalid_cursor()

  defp same_origin?(left, right) do
    left.scheme == right.scheme and left.host == right.host and
      normalized_port(left) == normalized_port(right)
  end

  defp normalized_port(%URI{port: nil, scheme: "https"}), do: 443
  defp normalized_port(%URI{port: nil, scheme: "http"}), do: 80
  defp normalized_port(%URI{port: port}), do: port

  defp same_path?(left, right) when is_binary(left) and is_binary(right) do
    URI.decode(left) == URI.decode(right)
  rescue
    ArgumentError -> false
  end

  defp same_path?(_left, _right), do: false

  defp present?(value), do: is_binary(value) and value != ""

  defp invalid_cursor,
    do: {:error, Error.config("SharePoint delta cursor is invalid", key: :cursor)}
end
