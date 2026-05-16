defmodule Jido.Connect.Airtable.Handlers.Actions.CreateRecords do
  @moduledoc false

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  @max_batch_size 10

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- validate_batch_records(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, records} <- client.create_records(input, token) do
      {:ok, %{records: ResourceHelpers.public_map(records)}}
    end
  end

  defp validate_batch_records(%{records: records} = input) when is_list(records) do
    cond do
      records == [] ->
        {:error,
         Jido.Connect.Error.validation("records list must not be empty",
           reason: :invalid_batch_records
         )}

      length(records) > @max_batch_size ->
        {:error,
         Jido.Connect.Error.validation("batch size exceeds maximum of #{@max_batch_size}",
           reason: :batch_size_exceeded
         )}

      true ->
        {:ok, input}
    end
  end

  defp validate_batch_records(_input) do
    {:error,
     Jido.Connect.Error.validation("records must be a list",
       reason: :invalid_batch_records
     )}
  end
end
