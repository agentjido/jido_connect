defmodule Jido.Connect.Google.Drive.Handlers.Actions.UpdateComment do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with :ok <- require_present(input, :content, "Google Drive comment update requires content"),
         {:ok, client} <- fetch_client(credentials),
         {:ok, comment} <-
           client.update_comment(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{comment: public_map(comment)}}
    end
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

  defp normalize_input(input), do: trim_string(input, :content)

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end

  defp validation_error(message, details) do
    {:error, Error.validation(message, reason: :invalid_comment, details: Map.new(details))}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
