defmodule Jido.Connect.Google.Drive.Handlers.Actions.DeletePermission do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.delete_permission(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{result: result}}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:supports_all_drives, false)
    |> Map.put_new(:use_domain_admin_access, false)
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
