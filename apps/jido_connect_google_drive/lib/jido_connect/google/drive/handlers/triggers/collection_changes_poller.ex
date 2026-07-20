defmodule Jido.Connect.Google.Drive.Handlers.Triggers.CollectionChangesPoller do
  @moduledoc false

  alias Jido.Connect.Google.Drive.{Client, CollectionChanges}

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      access_token = Map.get(credentials, :access_token)

      if checkpoint in [nil, ""] do
        CollectionChanges.init_checkpoint(client, config, access_token)
      else
        CollectionChanges.list(client, config, checkpoint, access_token)
      end
    end
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
