defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetCalendar do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :calendar_id) do
      nil ->
        {:error, :calendar_id_required}

      calendar_id ->
        request = Transport.request(access_token)

        case Transport.request(request, :get, url: "/me/calendars/#{calendar_id}") do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.calendar(body) do
              {:ok, calendar} -> {:ok, %{calendar: calendar}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Microsoft calendar"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error, message: "Failed to get Microsoft calendar")
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
