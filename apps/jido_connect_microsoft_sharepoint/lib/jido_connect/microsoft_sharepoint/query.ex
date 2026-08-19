defmodule Jido.Connect.MicrosoftSharepoint.Query do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Microsoft.Pagination

  @operators ~w(eq ne lt le gt ge startswith)
  @field_pattern ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/

  @spec page(map(), map()) :: map()
  def page(input, base \\ %{}) do
    Pagination.query(base,
      page_size: Map.get(input, :page_size, 25),
      skip: Map.get(input, :skip)
    )
  end

  @spec item_params(map()) :: {:ok, map()} | {:error, Error.ConfigError.t()}
  def item_params(input) do
    with {:ok, expand} <- fields_expand(Map.get(input, :fields)),
         {:ok, filter} <- filter(input) do
      params =
        input
        |> page()
        |> Map.put(:"$expand", expand)
        |> maybe_put(:"$filter", filter)

      {:ok, params}
    end
  end

  @spec write_fields(term()) :: {:ok, map()} | {:error, Error.ConfigError.t()}
  def write_fields(fields)
      when is_map(fields) and map_size(fields) > 0 and map_size(fields) <= 200 do
    normalized = Map.new(fields, fn {key, value} -> {to_string(key), value} end)

    if Enum.all?(Map.keys(normalized), &valid_field?/1) do
      {:ok, normalized}
    else
      {:error,
       Error.config("SharePoint field values contain an invalid field name", key: :fields)}
    end
  end

  def write_fields(_fields),
    do: {:error, Error.config("SharePoint field values are required", key: :fields)}

  @spec etag(term()) :: {:ok, String.t()} | {:error, Error.ConfigError.t()}
  def etag(value) when is_binary(value) and byte_size(value) <= 512 do
    if String.trim(value) == "" do
      {:error, Error.config("SharePoint item ETag is required", key: :etag)}
    else
      {:ok, value}
    end
  end

  def etag(_value), do: {:error, Error.config("SharePoint item ETag is required", key: :etag)}

  defp fields_expand(nil), do: {:ok, "fields"}
  defp fields_expand([]), do: {:ok, "fields"}

  defp fields_expand(fields) when is_list(fields) do
    if length(fields) <= 50 and Enum.all?(fields, &valid_field?/1) do
      {:ok, "fields(select=#{Enum.join(fields, ",")})"}
    else
      {:error, Error.config("SharePoint field selection is invalid", key: :fields)}
    end
  end

  defp fields_expand(_fields),
    do: {:error, Error.config("SharePoint field selection is invalid", key: :fields)}

  defp filter(input) do
    field = Map.get(input, :filter_field)
    operator = Map.get(input, :filter_operator)

    value_present? =
      Map.has_key?(input, :filter_value) and not is_nil(Map.get(input, :filter_value))

    cond do
      is_nil(field) and is_nil(operator) and not value_present? ->
        {:ok, nil}

      not valid_field?(field) ->
        {:error, Error.config("SharePoint filter field is invalid", key: :filter_field)}

      operator not in @operators ->
        {:error, Error.config("SharePoint filter operator is invalid", key: :filter_operator)}

      not value_present? ->
        {:error, Error.config("SharePoint filter value is required", key: :filter_value)}

      operator == "startswith" ->
        {:ok, "startswith(fields/#{field},#{literal(Map.get(input, :filter_value))})"}

      true ->
        {:ok, "fields/#{field} #{operator} #{literal(Map.get(input, :filter_value))}"}
    end
  end

  defp literal(value) when is_binary(value), do: "'#{String.replace(value, "'", "''")}'"
  defp literal(value) when is_boolean(value), do: to_string(value)
  defp literal(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp literal(value), do: "'#{value |> to_string() |> String.replace("'", "''")}'"

  defp valid_field?(field), do: is_binary(field) and Regex.match?(@field_pattern, field)
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
