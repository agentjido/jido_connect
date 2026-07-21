defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.CancelEvent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Cancels a Microsoft Calendar event and sends cancellation notices to attendees.

  POST /me/events/{event_id}/cancel with an optional comment.
  Returns 204 No Content on success.

  Unlike delete (which silently removes the event), cancel sends cancellation
  notifications to all attendees. Only the organizer can cancel an event.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :event_id) do
      nil ->
        {:error, :event_id_required}

      event_id ->
        body = build_cancel_body(input)
        request = Transport.request(access_token)

        case Transport.request(request, :post,
               url: "/me/events/#{event_id}/cancel",
               json: body
             ) do
          {:ok, %{status: 204}} ->
            {:ok, %{cancelled: true, event_id: event_id}}

          {:ok, %{status: status}} when status in 200..299 ->
            {:ok, %{cancelled: true, event_id: event_id}}

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to cancel Microsoft calendar event"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to cancel Microsoft calendar event"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_cancel_body(input) do
    case Map.get(input, :comment) do
      nil -> %{}
      comment -> %{"comment" => comment}
    end
  end
end
