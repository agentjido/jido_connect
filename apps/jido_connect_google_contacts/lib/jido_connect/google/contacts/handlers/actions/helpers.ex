defmodule Jido.Connect.Google.Contacts.Handlers.Actions.Helpers do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Contacts.Client

  def fetch_client(%{google_contacts_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()

  def public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  def public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)
  def public_map(value), do: value

  def people_result(result) do
    %{
      people: Enum.map(Map.get(result, :people, []), &public_map/1),
      next_page_token: Map.get(result, :next_page_token),
      next_sync_token: Map.get(result, :next_sync_token),
      total_items: Map.get(result, :total_items),
      total_size: Map.get(result, :total_size),
      responses: public_map(Map.get(result, :responses))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  def validate_resource_names(input, reason) do
    case Data.get(input, :resource_names) do
      values when is_list(values) and values != [] ->
        validate_string_list(values, :resource_names, reason)

      _missing ->
        validation_error(:resource_names, reason)
    end
  end

  def validate_contacts(input, reason, opts \\ []) do
    case Data.get(input, :contacts) do
      contacts when is_list(contacts) and contacts != [] ->
        contacts
        |> Enum.reduce_while(:ok, fn contact, :ok ->
          with :ok <-
                 validate_contact_field(
                   contact,
                   :resource_name,
                   reason,
                   Keyword.get(opts, :resource_name?, false)
                 ),
               :ok <-
                 validate_contact_field(contact, :etag, reason, Keyword.get(opts, :etag?, false)) do
            {:cont, :ok}
          else
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      _missing ->
        validation_error(:contacts, reason)
    end
  end

  def require_present(input, field, reason) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: validation_error(field, reason), else: :ok

      _missing ->
        validation_error(field, reason)
    end
  end

  def require_string(input, field, reason) do
    case Data.get(input, field) do
      value when is_binary(value) -> :ok
      _missing -> validation_error(field, reason)
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

  defp validate_contact_field(_contact, _field, _reason, false), do: :ok

  defp validate_contact_field(contact, field, reason, true),
    do: require_present(contact, field, reason)

  defp validate_string_list(values, field, reason) do
    if Enum.all?(values, &(is_binary(&1) and String.trim(&1) != "")) do
      :ok
    else
      validation_error(field, reason)
    end
  end

  defp validation_error(field, reason) do
    {:error,
     Error.validation("Google Contacts #{field} is invalid",
       reason: reason,
       details: %{field: field}
     )}
  end
end
