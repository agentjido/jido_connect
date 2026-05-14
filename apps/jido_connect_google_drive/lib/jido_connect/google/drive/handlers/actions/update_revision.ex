defmodule Jido.Connect.Google.Drive.Handlers.Actions.UpdateRevision do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  @mutable_fields [:keep_forever, :published, :publish_auto, :published_outside_domain]

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, revision} <-
           client.update_revision(input, Map.get(credentials, :access_token)) do
      {:ok, %{revision: public_map(revision)}}
    end
  end

  defp validate_input(input) do
    if Enum.any?(@mutable_fields, &(Data.get(input, &1) != nil)) do
      :ok
    else
      {:error,
       Error.validation("Google Drive revision update requires mutable fields",
         reason: :invalid_revision,
         details: %{field: :revision_update}
       )}
    end
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
