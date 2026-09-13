defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItem do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.{DriveTarget, Normalizer}

  @doc """
  Uploads or replaces a file in Microsoft OneDrive using the simple upload API.

  Supports:
  - `name` (required) - file name
  - `content` (optional) - file content as binary string
  - `parent_id` (optional) - parent folder; defaults to drive root
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    name = Map.get(input, :name)
    content = Map.get(input, :content, "")
    parent_id = Map.get(input, :parent_id)

    case name do
      nil ->
        {:error, :name_required}

      _ ->
        with {:ok, url} <- DriveTarget.upload(input, parent_id, name) do
          request = Transport.request(access_token)

          case Transport.request(request, :put, url: url, body: content) do
            {:ok, %{status: 201, body: resp_body}} when is_map(resp_body) ->
              case Normalizer.drive_item(resp_body) do
                {:ok, item} -> {:ok, %{item: item}}
                {:error, _reason} = error -> error
              end

            {:ok, %{status: 200, body: resp_body}} when is_map(resp_body) ->
              case Normalizer.drive_item(resp_body) do
                {:ok, item} -> {:ok, %{item: item}}
                {:error, _reason} = error -> error
              end

            {:ok, response} ->
              Transport.handle_error_response({:ok, response},
                message: "Failed to upload Microsoft OneDrive file"
              )

            {:error, _reason} = error ->
              Transport.handle_error_response(error,
                message: "Failed to upload Microsoft OneDrive file"
              )
          end
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
