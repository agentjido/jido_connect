defmodule Jido.Connect.Google.Drive.Handlers.Actions.CreateSharedDrive do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with :ok <-
           require_present(
             input,
             :request_id,
             "Google Drive shared-drive create requires request_id"
           ),
         :ok <- require_present(input, :name, "Google Drive shared-drive create requires name"),
         {:ok, client} <- fetch_client(credentials),
         {:ok, shared_drive} <-
           client.create_shared_drive(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{shared_drive: public_map(shared_drive)}}
    end
  end

  defp normalize_input(input) do
    input
    |> trim_string(:request_id)
    |> trim_string(:name)
  end

  defp require_present(input, field, message) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          validation_error(message, field: field)
        else
          :ok
        end

      _missing ->
        validation_error(message, field: field)
    end
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end

  defp validation_error(message, details) do
    {:error, Error.validation(message, reason: :invalid_shared_drive, details: Map.new(details))}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
