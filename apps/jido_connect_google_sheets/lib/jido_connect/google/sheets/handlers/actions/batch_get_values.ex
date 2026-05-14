defmodule Jido.Connect.Google.Sheets.Handlers.Actions.BatchGetValues do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Sheets.Client}

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_ranges(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.batch_get_values(input, Map.get(credentials, :access_token)) do
      {:ok, public_map(result)}
    end
  end

  defp validate_ranges(%{ranges: ranges}) when is_list(ranges) and ranges != [] do
    if Enum.all?(ranges, &valid_range?/1) do
      :ok
    else
      invalid_ranges(%{expected: "non-empty A1 range strings"})
    end
  end

  defp validate_ranges(_input), do: invalid_ranges(%{expected: "non-empty list"})

  defp valid_range?(range), do: is_binary(range) and String.trim(range) != ""

  defp invalid_ranges(details) do
    {:error,
     Error.validation("Batch get ranges must be non-empty A1 range strings",
       reason: :invalid_batch_get_values_ranges,
       details: details
     )}
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map) do
    Map.update(map, :value_ranges, [], fn ranges -> Enum.map(ranges, &public_map/1) end)
  end

  defp public_map(value), do: value
end
