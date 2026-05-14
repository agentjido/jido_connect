defmodule Jido.Connect.Google.Calendar.Handlers.Actions.ResourceHelpers do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Calendar.Client

  def fetch_client(%{google_calendar_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(map) when is_map(map), do: map
  def public_map(value), do: value

  def require_present(input, field, reason) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          invalid_field(field, reason)
        else
          :ok
        end

      _missing ->
        invalid_field(field, reason)
    end
  end

  def validate_enum(input, field, allowed, reason) do
    case Data.get(input, field) do
      nil ->
        :ok

      value ->
        if value in allowed do
          :ok
        else
          validation_error("Google Calendar #{field} is invalid",
            reason: reason,
            details: %{field: field, value: value, allowed: allowed}
          )
        end
    end
  end

  def normalize_input(input, defaults, trim_fields) do
    Enum.reduce(trim_fields, Map.merge(defaults, input), &trim_string(&2, &1))
  end

  def validation_error(message, opts) do
    {:error,
     Error.validation(message,
       reason: Keyword.fetch!(opts, :reason),
       details: Keyword.get(opts, :details, %{})
     )}
  end

  defp invalid_field(field, reason) do
    validation_error("Google Calendar #{field} must be a non-empty string",
      reason: reason,
      details: %{field: field}
    )
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end
end
