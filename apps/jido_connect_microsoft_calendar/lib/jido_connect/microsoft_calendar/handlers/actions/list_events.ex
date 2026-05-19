defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListEvents do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  @doc """
  Lists events from the authenticated user's calendar via Microsoft Graph.

  Supports:
  - `calendar_id` (optional) - targets a specific calendar
  - `start_date_time` / `end_date_time` - date range filter; when both are
    provided the handler uses the `calendarView` endpoint for reliable
    date-range queries
  - `page_size` (default: 25) - maps to `$top`
  - `skip` - maps to `$skip` for manual paging
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)
    calendar_id = Map.get(input, :calendar_id)
    start_dt = Map.get(input, :start_date_time)
    end_dt = Map.get(input, :end_date_time)

    {url, extra_params} = build_url_and_params(calendar_id, start_dt, end_dt)

    params =
      extra_params
      |> Pagination.query(page_size: Map.get(input, :page_size, 25), skip: Map.get(input, :skip))

    case Transport.request(request, :get, url: url, params: params) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Normalizer.page(body, &Normalizer.event/1) do
          {:ok, %{items: events, next_link: next_link}} ->
            {:ok, %{events: events, next_link: next_link}}

          {:error, _reason} = error ->
            error
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to list Microsoft calendar events"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error,
          message: "Failed to list Microsoft calendar events"
        )
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_url_and_params(calendar_id, start_dt, end_dt)
       when is_binary(start_dt) and start_dt != "" and is_binary(end_dt) and end_dt != "" do
    base = calendar_path(calendar_id, "calendarView")
    params = %{startDateTime: start_dt, endDateTime: end_dt}
    {base, params}
  end

  defp build_url_and_params(calendar_id, _start_dt, _end_dt) do
    {calendar_path(calendar_id, "events"), %{}}
  end

  defp calendar_path(nil, suffix), do: "/me/calendar/#{suffix}"
  defp calendar_path(id, suffix), do: "/me/calendars/#{id}/#{suffix}"
end
