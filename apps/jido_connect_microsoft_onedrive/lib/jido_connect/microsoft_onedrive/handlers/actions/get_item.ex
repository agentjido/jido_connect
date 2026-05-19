defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetItem do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :item_id) do
      nil ->
        {:error, :item_id_required}

      item_id ->
        request = Transport.request(access_token)
        url = "/me/drive/items/#{item_id}"

        case Transport.request(request, :get, url: url) do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.drive_item(body) do
              {:ok, item} -> {:ok, %{item: item}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Microsoft OneDrive item"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to get Microsoft OneDrive item"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
