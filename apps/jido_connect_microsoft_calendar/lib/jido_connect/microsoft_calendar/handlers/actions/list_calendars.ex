defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListCalendars do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  @doc """
  Lists calendars for the authenticated user via Microsoft Graph.

  Supports:
  - `page_size` (default: 25) - maps to `$top`
  - `skip` - maps to `$skip` for manual paging
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)

    params =
      Pagination.query(%{},
        page_size: Map.get(input, :page_size, 25),
        skip: Map.get(input, :skip)
      )

    case Transport.request(request, :get, url: "/me/calendars", params: params) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Normalizer.page(body, &Normalizer.calendar/1) do
          {:ok, %{items: calendars, next_link: next_link}} ->
            {:ok, %{calendars: calendars, next_link: next_link}}

          {:error, _reason} = error ->
            error
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to list Microsoft calendars"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: "Failed to list Microsoft calendars")
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
