defmodule Jido.Connect.Google.Sheets.Handlers.Actions.BatchUpdateValues do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Sheets.Client}

  @max_ranges 100

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_data(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.batch_update_values(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{batch_update: public_map(result)}}
    end
  end

  defp validate_data(%{data: data}) when is_list(data) do
    cond do
      data == [] ->
        invalid_data(%{expected: "non-empty list"})

      length(data) > @max_ranges ->
        invalid_data(%{max_ranges: @max_ranges, range_count: length(data)})

      true ->
        validate_entries(data)
    end
  end

  defp validate_data(_input), do: invalid_data(%{expected: :list})

  defp validate_entries(data) do
    data
    |> Enum.with_index()
    |> Enum.find_value(fn {entry, index} ->
      cond do
        not is_map(entry) ->
          invalid_entry(index, "entry must be a map")

        not valid_range?(Map.get(entry, :range)) ->
          invalid_entry(index, "range must be a non-empty A1 range string")

        not is_list(Map.get(entry, :values)) ->
          invalid_entry(index, "values must be a list of rows")

        true ->
          nil
      end
    end)
    |> case do
      nil -> :ok
      error -> error
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:value_input_option, "RAW")
    |> Map.put_new(:include_values_in_response, false)
    |> Map.update!(:data, fn data ->
      Enum.map(data, &Map.put_new(&1, :major_dimension, "ROWS"))
    end)
  end

  defp valid_range?(range), do: is_binary(range) and String.trim(range) != ""

  defp invalid_data(details) do
    {:error,
     Error.validation("Batch update values data must be a non-empty list",
       reason: :invalid_batch_update_values_data,
       details: details
     )}
  end

  defp invalid_entry(index, message) do
    {:error,
     Error.validation("Invalid batch update values entry",
       reason: :invalid_batch_update_values_entry,
       details: %{index: index, message: message}
     )}
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map) do
    Map.update(map, :responses, [], fn responses -> Enum.map(responses, &public_map/1) end)
  end

  defp public_map(value), do: value
end
