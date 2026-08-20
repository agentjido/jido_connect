defmodule Jido.Connect.Jira.Client.Normalizer.Value do
  @moduledoc false

  alias Jido.Connect.Data

  def get(map, key), do: Data.get(map, key)

  def id(value) when is_integer(value) and value > 0, do: {:ok, Integer.to_string(value)}

  def id(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, Integer.to_string(integer)}
      _other -> :error
    end
  end

  def id(_value), do: :error

  def required_string(value) when is_binary(value) and value != "", do: {:ok, value}
  def required_string(_value), do: :error

  def optional_string(nil), do: {:ok, nil}
  def optional_string(value), do: required_string(value)

  def optional_map(nil), do: {:ok, nil}
  def optional_map(value) when is_map(value), do: {:ok, value}
  def optional_map(_value), do: :error

  def optional_map_list(nil), do: {:ok, []}

  def optional_map_list(value) when is_list(value) do
    if Enum.all?(value, &is_map/1), do: {:ok, value}, else: :error
  end

  def optional_map_list(_value), do: :error

  def boolean(value) when is_boolean(value), do: {:ok, value}
  def boolean(_value), do: :error

  def optional_boolean(nil), do: {:ok, nil}
  def optional_boolean(value), do: boolean(value)

  def non_negative(value) when is_integer(value) and value >= 0, do: {:ok, value}
  def non_negative(_value), do: :error

  def optional_non_negative(nil), do: {:ok, nil}
  def optional_non_negative(value), do: non_negative(value)

  def positive(value) when is_integer(value) and value > 0, do: {:ok, value}
  def positive(_value), do: :error

  def optional_cursor(nil), do: {:ok, nil}
  def optional_cursor(""), do: {:ok, nil}
  def optional_cursor(value), do: required_string(value)

  def https_url(value) when is_binary(value) do
    uri = URI.parse(value)

    if uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and is_nil(uri.userinfo),
      do: {:ok, value},
      else: :error
  end

  def https_url(_value), do: :error
end
