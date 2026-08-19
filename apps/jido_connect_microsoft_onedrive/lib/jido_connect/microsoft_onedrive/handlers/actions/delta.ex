defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Delta do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftOnedrive.{DriveTarget, Normalizer}

  @doc """
  Tracks changes to drive items using the Microsoft Graph delta endpoint.

  Supports:
  - `token` (optional) - delta token from a previous delta response for incremental sync.
    Omit for initial full sync.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    token = Map.get(input, :token)

    with {:ok, url} <- DriveTarget.delta(input, token) do
      request = Transport.request(access_token)
      params = Pagination.query(%{})

      case Transport.request(request, :get, url: url, params: params) do
        {:ok, %{status: 200, body: body}} when is_map(body) ->
          case Normalizer.page(body, &Normalizer.drive_item/1) do
            {:ok, %{items: items, next_link: next_link}} ->
              delta_link = Data.get(body, "@odata.deltaLink")
              delta_token = Data.get(body, "@odata.deltaToken")

              {:ok,
               %{
                 items: items,
                 next_link: next_link,
                 delta_link: delta_link,
                 delta_token: delta_token
               }}

            {:error, _reason} = error ->
              error
          end

        {:ok, response} ->
          Transport.handle_error_response({:ok, response},
            message: "Failed to read Microsoft OneDrive delta changes"
          )

        {:error, _reason} = error ->
          Transport.handle_error_response(error,
            message: "Failed to read Microsoft OneDrive delta changes"
          )
      end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
