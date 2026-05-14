defmodule Jido.Connect.Gmail.Handlers.Actions.Mutation do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Gmail.Client

  def run_client(input, credentials, client_fun, output_key) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- apply(client, client_fun, [input, Map.get(credentials, :access_token)]) do
      {:ok, %{output_key => public_map(result)}}
    end
  end

  def fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  def public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  def public_map(value), do: value

  def normalize_required_id(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        value = String.trim(value)

        if value == "" do
          invalid_id(field)
        else
          {:ok, Map.put(input, field, value)}
        end

      _missing ->
        invalid_id(field)
    end
  end

  def normalize_required_ids(input, field) do
    case Data.get(input, field) do
      values when is_list(values) ->
        with {:ok, values} <- normalize_string_list(values, field) do
          if values == [] do
            invalid_ids(field)
          else
            {:ok, Map.put(input, field, values)}
          end
        end

      _invalid ->
        invalid_ids(field)
    end
  end

  def normalize_label_mutation(input) do
    with {:ok, add_label_ids} <-
           normalize_string_list(Data.get(input, :add_label_ids, []), :add_label_ids),
         {:ok, remove_label_ids} <-
           normalize_string_list(Data.get(input, :remove_label_ids, []), :remove_label_ids) do
      input =
        input
        |> Map.put(:add_label_ids, add_label_ids)
        |> Map.put(:remove_label_ids, remove_label_ids)

      cond do
        add_label_ids == [] and remove_label_ids == [] ->
          validation_error(
            "Gmail label mutation requires add_label_ids or remove_label_ids",
            :invalid_label_mutation,
            %{field: :labels}
          )

        true ->
          {:ok, input}
      end
    end
  end

  def normalize_label_update(input) do
    with {:ok, input} <- normalize_optional_name(input) do
      if label_update_empty?(input) do
        validation_error("Gmail label update requires mutable label fields", :invalid_label, %{
          field: :label
        })
      else
        {:ok, input}
      end
    end
  end

  defp normalize_optional_name(input) do
    case Data.get(input, :name) do
      nil ->
        {:ok, input}

      name when is_binary(name) ->
        trimmed_name = String.trim(name)

        if trimmed_name == "" do
          validation_error("Gmail label name must not be blank", :invalid_label, %{field: :name})
        else
          {:ok, Map.put(input, :name, trimmed_name)}
        end

      _invalid ->
        validation_error("Gmail label name must be a string", :invalid_label, %{field: :name})
    end
  end

  defp label_update_empty?(input) do
    input
    |> Map.take([:name, :message_list_visibility, :label_list_visibility, :color])
    |> Enum.all?(fn {_key, value} -> is_nil(value) or value == "" or value == %{} end)
  end

  defp normalize_string_list(values, field) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn
      value, {:ok, acc} when is_binary(value) ->
        case String.trim(value) do
          "" -> {:halt, invalid_ids(field)}
          value -> {:cont, {:ok, [value | acc]}}
        end

      _invalid, {:ok, _acc} ->
        {:halt, invalid_ids(field)}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_string_list(_values, field), do: invalid_ids(field)

  defp invalid_id(field) do
    validation_error("Gmail #{field} must be a non-empty string", :invalid_gmail_id, %{
      field: field,
      expected: "non-empty string"
    })
  end

  defp invalid_ids(field) do
    validation_error("Gmail #{field} must contain non-empty strings", :invalid_gmail_ids, %{
      field: field,
      expected: "non-empty string list"
    })
  end

  defp validation_error(message, reason, details) do
    {:error, Error.validation(message, reason: reason, details: details)}
  end
end
