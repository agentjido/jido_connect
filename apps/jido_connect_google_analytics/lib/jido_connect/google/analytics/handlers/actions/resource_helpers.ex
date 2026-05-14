defmodule Jido.Connect.Google.Analytics.Handlers.Actions.ResourceHelpers do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Analytics.Client

  def fetch_client(%{google_analytics_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(map) when is_map(map), do: map
  def public_map(value), do: value

  def metadata_input(input) do
    case normalize_property(Data.get(input, :property)) do
      {:ok, property} ->
        {:ok,
         input
         |> Map.put(:property, property)
         |> trim_string(:fields)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_property(value) when is_binary(value) do
    case String.trim(value) do
      "" -> invalid_property()
      "properties/" <> _rest = property -> {:ok, property}
      property_id -> {:ok, "properties/#{property_id}"}
    end
  end

  defp normalize_property(_value), do: invalid_property()

  defp invalid_property do
    {:error,
     Error.validation("Google Analytics property must be a non-empty string",
       reason: :invalid_property,
       details: %{field: :property}
     )}
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end
end
