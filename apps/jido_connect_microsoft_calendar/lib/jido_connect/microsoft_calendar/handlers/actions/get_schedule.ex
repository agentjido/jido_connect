defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetSchedule do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  @doc """
  Gets free/busy availability for users or resources via Microsoft Graph
  `calendar/getSchedule`.

  Input:
  - `schedules` (required) - list of email addresses
  - `start_date_time` (required) - ISO 8601 start
  - `end_date_time` (required) - ISO 8601 end
  - `time_zone` (default: "UTC") - timezone for the query window
  - `availability_view_interval` (default: 30) - minutes per slot
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case {Map.get(input, :schedules), Map.get(input, :start_date_time),
          Map.get(input, :end_date_time)} do
      {schedules, start_dt, end_dt}
      when is_list(schedules) and length(schedules) > 0 and is_binary(start_dt) and
             is_binary(end_dt) and start_dt != "" and end_dt != "" ->
        request = Transport.request(access_token)
        time_zone = Map.get(input, :time_zone, "UTC")

        body = %{
          schedules: schedules,
          startTime: %{dateTime: start_dt, timeZone: time_zone},
          endTime: %{dateTime: end_dt, timeZone: time_zone}
        }

        body =
          case Map.get(input, :availability_view_interval) do
            nil -> body
            interval -> Map.put(body, :availabilityViewInterval, interval)
          end

        case Transport.request(request, :post,
               url: "/me/calendar/getSchedule",
               json: body
             ) do
          {:ok, %{status: 200, body: %{"value" => values}}}
          when is_list(values) ->
            case Normalizer.normalize_list(values, &Normalizer.availability_result/1) do
              {:ok, results} -> {:ok, %{results: results}}
              {:error, _reason} = error -> error
            end

          {:ok, %{status: 200, body: body}} when is_map(body) ->
            Transport.invalid_success_response(
              "Missing value array in getSchedule response",
              body
            )

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Microsoft calendar schedule"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to get Microsoft calendar schedule"
            )
        end

      {_, _, _} ->
        {:error, :invalid_schedule_input}
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
