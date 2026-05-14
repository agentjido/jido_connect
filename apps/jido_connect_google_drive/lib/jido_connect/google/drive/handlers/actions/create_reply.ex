defmodule Jido.Connect.Google.Drive.Handlers.Actions.CreateReply do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  @mutable_fields [:content, :action]

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_has_payload(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, reply} <-
           client.create_reply(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{reply: public_map(reply)}}
    end
  end

  defp validate_has_payload(input) do
    if Enum.any?(@mutable_fields, &present?(input, &1)) do
      :ok
    else
      validation_error("Google Drive reply create requires content or action",
        field: :reply_create
      )
    end
  end

  defp present?(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> String.trim(value) != ""
      value -> value != nil
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
    {:error, Error.validation(message, reason: :invalid_reply, details: Map.new(details))}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
