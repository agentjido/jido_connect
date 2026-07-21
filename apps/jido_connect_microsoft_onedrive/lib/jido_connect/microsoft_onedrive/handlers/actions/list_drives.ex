defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListDrives do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  @doc """
  Lists drives available to the authenticated user via Microsoft Graph.

  Supports:
  - `page_size` (default: 25) - maps to `$top`
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)
    params = Pagination.query(%{}, page_size: Map.get(input, :page_size, 25))

    case Transport.request(request, :get, url: "/me/drives", params: params) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Normalizer.page(body, &Normalizer.drive/1) do
          {:ok, %{items: drives, next_link: next_link}} ->
            {:ok, %{drives: drives, next_link: next_link}}

          {:error, _reason} = error ->
            error
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to list Microsoft OneDrive drives"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error,
          message: "Failed to list Microsoft OneDrive drives"
        )
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
