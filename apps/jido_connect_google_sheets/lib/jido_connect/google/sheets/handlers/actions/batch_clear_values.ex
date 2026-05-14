defmodule Jido.Connect.Google.Sheets.Handlers.Actions.BatchClearValues do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Sheets.Client}

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_ranges(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.batch_clear_values(input, Map.get(credentials, :access_token)) do
      {:ok, %{batch_clear: result}}
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
     Error.validation("Batch clear ranges must be non-empty A1 range strings",
       reason: :invalid_batch_clear_values_ranges,
       details: details
     )}
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
