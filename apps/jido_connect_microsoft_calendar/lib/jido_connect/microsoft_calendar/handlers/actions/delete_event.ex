defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeleteEvent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Deletes a Microsoft Calendar event via Microsoft Graph.

  DELETE /me/events/{event_id} or DELETE /me/calendars/{calendar_id}/events/{event_id}.
  Returns 204 No Content on success.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :event_id) do
      nil ->
        {:error, :event_id_required}

      event_id ->
        request = Transport.request(access_token)
        url = event_url(Map.get(input, :calendar_id), event_id)

        case Transport.request(request, :delete, url: url) do
          {:ok, %{status: 204}} ->
            {:ok, %{deleted: true, event_id: event_id}}

          {:ok, %{status: status}} when status in 200..299 ->
            {:ok, %{deleted: true, event_id: event_id}}

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to delete Microsoft calendar event"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to delete Microsoft calendar event"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp event_url(nil, event_id), do: "/me/events/#{event_id}"
  defp event_url(calendar_id, event_id), do: "/me/calendars/#{calendar_id}/events/#{event_id}"
end
