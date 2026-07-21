defmodule Jido.Connect.Airtable.Handlers.Actions.DeleteRecords do
  @moduledoc false

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  @max_batch_size 10

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- validate_batch_ids(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, records} <- client.delete_records(input, token) do
      {:ok, %{records: ResourceHelpers.public_map(records)}}
    end
  end

  defp validate_batch_ids(%{record_ids: record_ids} = input) when is_list(record_ids) do
    cond do
      record_ids == [] ->
        {:error,
         Jido.Connect.Error.validation("record_ids list must not be empty",
           reason: :invalid_batch_records
         )}

      length(record_ids) > @max_batch_size ->
        {:error,
         Jido.Connect.Error.validation("batch size exceeds maximum of #{@max_batch_size}",
           reason: :batch_size_exceeded
         )}

      true ->
        {:ok, input}
    end
  end

  defp validate_batch_ids(_input) do
    {:error,
     Jido.Connect.Error.validation("record_ids must be a list",
       reason: :invalid_batch_records
     )}
  end
end
