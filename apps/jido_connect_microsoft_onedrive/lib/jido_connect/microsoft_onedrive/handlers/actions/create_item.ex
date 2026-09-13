defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.{DriveTarget, Normalizer}

  @doc """
  Creates a new folder or file in Microsoft OneDrive.

  Supports:
  - `name` (required) - the item name
  - `type` (default: "folder") - item type to create
  - `parent_id` (optional) - parent folder; defaults to drive root
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    name = Map.get(input, :name)
    type = Map.get(input, :type, "folder")
    parent_id = Map.get(input, :parent_id)

    case name do
      nil ->
        {:error, :name_required}

      _ ->
        with {:ok, url} <- DriveTarget.children(input, parent_id) do
          body = build_body(name, type)
          request = Transport.request(access_token)

          case Transport.request(request, :post, url: url, json: body) do
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
                message: "Failed to create Microsoft OneDrive item"
              )

            {:error, _reason} = error ->
              Transport.handle_error_response(error,
                message: "Failed to create Microsoft OneDrive item"
              )
          end
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_body(name, "folder") do
    %{"name" => name, "folder" => %{}}
  end

  defp build_body(name, type) do
    %{"name" => name, type => %{}}
  end
end
