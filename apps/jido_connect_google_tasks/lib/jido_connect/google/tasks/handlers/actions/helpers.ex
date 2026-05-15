defmodule Jido.Connect.Google.Tasks.Handlers.Actions.Helpers do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Tasks.Client

  def fetch_client(%{google_tasks_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()

  def public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  def public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)
  def public_map(value), do: value

  def require_present(input, field, reason) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: field_error(field, reason), else: :ok

      _missing ->
        field_error(field, reason)
    end
  end

  def normalize_strings(input, fields) do
    Enum.reduce(fields, input, fn field, acc ->
      case Data.get(acc, field) do
        value when is_binary(value) -> Map.put(acc, field, String.trim(value))
        _other -> acc
      end
    end)
  end

  def validation_error(message, opts) do
    {:error,
     Error.validation(message,
       reason: Keyword.fetch!(opts, :reason),
       details: Keyword.get(opts, :details, %{})
     )}
  end

  def field_error(field, reason) do
    validation_error("Google Tasks #{field} is invalid",
      reason: reason,
      details: %{field: field}
    )
  end
end
