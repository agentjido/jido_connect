defmodule Jido.Connect.Google.Drive.Handlers.Actions.ListCollectionChanges do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.{Client, CollectionChanges}

  def run(input, %{credentials: credentials}) do
    with {:ok, checkpoint} <- fetch_checkpoint(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           CollectionChanges.list(
             client,
             input,
             checkpoint,
             Map.get(credentials, :access_token)
           ) do
      {:ok, result}
    end
  end

  defp fetch_checkpoint(input) do
    input
    |> checkpoint_candidates()
    |> Enum.find_value(&normalize_checkpoint/1)
    |> case do
      nil -> invalid_checkpoint()
      checkpoint -> {:ok, checkpoint}
    end
  end

  defp checkpoint_candidates(input),
    do: [Data.get(input, :checkpoint), Data.get(input, :cursor)]

  defp normalize_checkpoint(checkpoint) when is_binary(checkpoint) do
    case String.trim(checkpoint) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_checkpoint(_checkpoint), do: nil

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
