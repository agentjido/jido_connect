defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetEvent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :event_id) do
      nil ->
        {:error, :event_id_required}

      event_id ->
        request = Transport.request(access_token)
        url = event_url(Map.get(input, :calendar_id), event_id)

        case Transport.request(request, :get, url: url) do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.event(body) do
              {:ok, event} -> {:ok, %{event: event}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Microsoft calendar event"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to get Microsoft calendar event"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp event_url(nil, event_id), do: "/me/events/#{event_id}"
  defp event_url(calendar_id, event_id), do: "/me/calendars/#{calendar_id}/events/#{event_id}"
end
