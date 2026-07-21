defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetFolder do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOutlook.Normalizer

  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :folder_id) do
      nil ->
        {:error, :folder_id_required}

      folder_id ->
        request = Transport.request(access_token)

        case Transport.request(request, :get, url: "/me/mailFolders/#{folder_id}") do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.folder(body) do
              {:ok, folder} -> {:ok, %{folder: folder}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Outlook folder"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error, message: "Failed to get Outlook folder")
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
