defmodule Jido.Connect.Google.Drive.Handlers.Actions.GetRevision do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, revision} <-
           client.get_revision(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{revision: public_map(revision)}}
    end
  end

  defp normalize_input(input), do: Map.put_new(input, :acknowledge_abuse, false)

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
