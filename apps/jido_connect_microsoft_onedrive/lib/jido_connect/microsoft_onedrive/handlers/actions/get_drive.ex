defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetDrive do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  def run(_input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)

    case Transport.request(request, :get, url: "/me/drive") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Normalizer.drive(body) do
          {:ok, drive} -> {:ok, %{drive: drive}}
          {:error, _reason} = error -> error
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to get Microsoft OneDrive drive"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error,
          message: "Failed to get Microsoft OneDrive drive"
        )
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
