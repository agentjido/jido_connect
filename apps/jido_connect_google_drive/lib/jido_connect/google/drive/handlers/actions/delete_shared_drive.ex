defmodule Jido.Connect.Google.Drive.Handlers.Actions.DeleteSharedDrive do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_allow_item_deletion(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.delete_shared_drive(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{result: result}}
    end
  end

  defp validate_allow_item_deletion(input) do
    if Data.get(input, :allow_item_deletion) == true and
         Data.get(input, :use_domain_admin_access) != true do
      validation_error("Google Drive shared-drive item deletion requires domain admin access",
        field: :allow_item_deletion
      )
    else
      :ok
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:use_domain_admin_access, false)
    |> Map.put_new(:allow_item_deletion, false)
  end

  defp validation_error(message, details) do
    {:error, Error.validation(message, reason: :invalid_shared_drive, details: Map.new(details))}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
