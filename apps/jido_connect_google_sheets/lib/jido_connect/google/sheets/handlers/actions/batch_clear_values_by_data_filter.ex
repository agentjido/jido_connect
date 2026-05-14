defmodule Jido.Connect.Google.Sheets.Handlers.Actions.BatchClearValuesByDataFilter do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Sheets.Client, Google.Sheets.DataFilter}

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_data_filters(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.batch_clear_values_by_data_filter(input, Map.get(credentials, :access_token)) do
      {:ok, %{batch_clear: public_map(result)}}
    end
  end

  defp validate_data_filters(%{data_filters: data_filters}) do
    if DataFilter.valid_filters?(data_filters) do
      :ok
    else
      invalid_data_filters()
    end
  end

  defp validate_data_filters(_input), do: invalid_data_filters()

  defp invalid_data_filters do
    {:error,
     Error.validation("Data filters must be non-empty Google Sheets DataFilter maps",
       reason: :invalid_data_filters,
       details: %{expected: "non-empty list with exactly one DataFilter selector per map"}
     )}
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  defp public_map(value), do: value
end
