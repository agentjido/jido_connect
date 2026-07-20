defmodule Jido.Connect.Google.Drive.Handlers.Actions.ListCollectionChanges do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Drive.{Client, CollectionChanges}

  def run(input, %{credentials: credentials}) do
    with {:ok, checkpoint} <- fetch_checkpoint(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           CollectionChanges.list(
             client,
             CollectionChanges.normalize_config(input),
             checkpoint,
             Map.get(credentials, :access_token)
           ) do
      {:ok, result}
    end
  end

  defp fetch_checkpoint(input) do
    case Map.get(input, :cursor) || Map.get(input, :checkpoint) do
      cursor when is_binary(cursor) and cursor != "" -> {:ok, cursor}
      _other -> invalid_checkpoint()
    end
  end

  defp invalid_checkpoint do
    {:error,
     Error.validation(
       "A cursor or checkpoint is required to list Google Drive collection changes",
       field: :checkpoint,
       reason: :required
     )}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
