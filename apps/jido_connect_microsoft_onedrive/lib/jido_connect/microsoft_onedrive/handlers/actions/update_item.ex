defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItem do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.{DriveTarget, Normalizer}

  @doc """
  Updates metadata of an existing Microsoft OneDrive drive item.

  Supports:
  - `item_id` (required) - the drive item id
  - `name` (optional) - new name for the item
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :item_id) do
      nil ->
        {:error, :item_id_required}

      item_id ->
        with {:ok, url} <- DriveTarget.item(input, item_id) do
          body = build_body(input)
          request = Transport.request(access_token)

          case Transport.request(request, :patch,
                 url: url,
                 headers: etag_headers(input),
                 json: body
               ) do
            {:ok, %{status: 200, body: resp_body}} when is_map(resp_body) ->
              case Normalizer.drive_item(resp_body) do
                {:ok, item} -> {:ok, %{item: item}}
                {:error, _reason} = error -> error
              end

            {:ok, response} ->
              Transport.handle_error_response({:ok, response},
                message: "Failed to update Microsoft OneDrive item"
              )

            {:error, _reason} = error ->
              Transport.handle_error_response(error,
                message: "Failed to update Microsoft OneDrive item"
              )
          end
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_body(input) do
    input
    |> Map.take([:name])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp etag_headers(input) do
    case Map.get(input, :etag) do
      etag when is_binary(etag) and etag != "" -> [{"if-match", etag}]
      _other -> []
    end
  end
end
