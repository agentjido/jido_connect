defmodule Jido.Connect.MCP.SchemaCompatibility do
  @moduledoc false

  alias Jido.Connect.Data

  @spec compatible?(map(), map()) :: boolean()
  def compatible?(required, actual) when is_map(required) and is_map(actual) do
    type_compatible?(required, actual) and
      required_fields_compatible?(required, actual) and
      additional_properties_compatible?(required, actual) and
      properties_compatible?(required, actual) and
      items_compatible?(required, actual) and
      values_compatible?(required, actual) and
      alternatives_compatible?(required, actual) and
      lower_bounds_compatible?(required, actual) and
      upper_bounds_compatible?(required, actual) and
      exact_constraints_compatible?(required, actual) and
      unique_items_compatible?(required, actual)
  end

  def compatible?(_required, _actual), do: false

  defp type_compatible?(required, actual) do
    case {Data.get(required, :type), Data.get(actual, :type)} do
      {nil, nil} -> true
      {nil, _observed} -> false
      {_expected, nil} -> true
      {expected, expected} -> true
      {_expected, _observed} -> false
    end
  end

  defp required_fields_compatible?(required, actual) do
    expected = Data.get(required, :required, [])
    observed = Data.get(actual, :required, [])

    is_list(expected) and is_list(observed) and Enum.all?(observed, &(&1 in expected))
  end

  defp additional_properties_compatible?(required, actual) do
    Data.get(actual, :additionalProperties) != false or
      Data.get(required, :additionalProperties) == false
  end

  defp items_compatible?(required, actual) do
    case {Data.get(required, :items), Data.get(actual, :items)} do
      {nil, nil} -> true
      {nil, _observed} -> false
      {%{} = _expected, nil} -> true
      {%{} = expected, %{} = observed} -> compatible?(expected, observed)
      {_expected, _observed} -> false
    end
  end

  defp properties_compatible?(required, actual) do
    expected = Data.get(required, :properties, %{})
    observed = Data.get(actual, :properties, %{})

    is_map(expected) and is_map(observed) and
      Enum.all?(expected, fn {name, schema} ->
        case fetch_key(observed, name) do
          {:ok, observed_schema} -> compatible?(schema, observed_schema)
          :error -> additional_property_compatible?(schema, actual)
        end
      end)
  end

  defp additional_property_compatible?(required_schema, actual) do
    case Data.get(actual, :additionalProperties) do
      false -> false
      %{} = observed_schema -> compatible?(required_schema, observed_schema)
      _open -> true
    end
  end

  defp values_compatible?(required, actual) do
    case {allowed_values(required), allowed_values(actual)} do
      {:any, :any} -> true
      {:any, _observed} -> false
      {_expected, :any} -> true
      {expected, observed} -> Enum.all?(expected, &(&1 in observed))
    end
  end

  defp allowed_values(schema) do
    cond do
      not is_nil(Data.get(schema, :const)) -> [Data.get(schema, :const)]
      is_list(Data.get(schema, :enum)) -> Data.get(schema, :enum)
      true -> :any
    end
  end

  defp lower_bounds_compatible?(required, actual) do
    Enum.all?(~w(minimum exclusiveMinimum minLength minItems minProperties), fn key ->
      lower_bound_compatible?(Data.get(required, key), Data.get(actual, key))
    end)
  end

  defp upper_bounds_compatible?(required, actual) do
    Enum.all?(~w(maximum exclusiveMaximum maxLength maxItems maxProperties), fn key ->
      upper_bound_compatible?(Data.get(required, key), Data.get(actual, key))
    end)
  end

  defp lower_bound_compatible?(nil, nil), do: true
  defp lower_bound_compatible?(nil, _observed), do: false
  defp lower_bound_compatible?(_expected, nil), do: true

  defp lower_bound_compatible?(expected, observed)
       when is_number(expected) and is_number(observed),
       do: observed <= expected

  defp lower_bound_compatible?(_expected, _observed), do: false

  defp upper_bound_compatible?(nil, nil), do: true
  defp upper_bound_compatible?(nil, _observed), do: false
  defp upper_bound_compatible?(_expected, nil), do: true

  defp upper_bound_compatible?(expected, observed)
       when is_number(expected) and is_number(observed),
       do: observed >= expected

  defp upper_bound_compatible?(_expected, _observed), do: false

  defp exact_constraints_compatible?(required, actual) do
    Enum.all?(~w(pattern format multipleOf), fn key ->
      case {Data.get(required, key), Data.get(actual, key)} do
        {nil, nil} -> true
        {nil, _observed} -> false
        {_expected, nil} -> true
        {value, value} -> true
        {_expected, _observed} -> false
      end
    end)
  end

  defp unique_items_compatible?(required, actual) do
    Data.get(actual, :uniqueItems) != true or Data.get(required, :uniqueItems) == true
  end

  defp alternatives_compatible?(required, actual) do
    case {Data.get(required, :anyOf), Data.get(actual, :anyOf)} do
      {nil, nil} ->
        true

      {nil, _observed} ->
        false

      {expected, nil} when is_list(expected) ->
        Enum.all?(expected, &compatible?(&1, actual))

      {expected, observed} when is_list(expected) and is_list(observed) ->
        Enum.all?(expected, fn expected_choice ->
          Enum.any?(observed, &compatible?(expected_choice, &1))
        end)

      {_expected, _observed} ->
        false
    end
  end

  defp fetch_key(map, key) do
    string_key = to_string(key)

    Enum.find_value(map, :error, fn {candidate, value} ->
      if to_string(candidate) == string_key, do: {:ok, value}, else: false
    end)
  end
end
