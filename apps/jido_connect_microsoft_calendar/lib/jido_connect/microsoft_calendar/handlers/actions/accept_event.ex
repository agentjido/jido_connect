defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.AcceptEvent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Accepts a Microsoft Calendar event invitation.

  POST /me/events/{event_id}/accept with an optional comment.
  Returns 202 Accepted on success.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :event_id) do
      nil ->
        {:error, :event_id_required}

      event_id ->
        body = build_response_body(input)
        request = Transport.request(access_token)

        case Transport.request(request, :post,
               url: "/me/events/#{event_id}/accept",
               json: body
             ) do
          {:ok, %{status: 202}} ->
            {:ok, %{accepted: true, event_id: event_id}}

          {:ok, %{status: status}} when status in 200..299 ->
            {:ok, %{accepted: true, event_id: event_id}}

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to accept Microsoft calendar event"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to accept Microsoft calendar event"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_response_body(input) do
    case Map.get(input, :comment) do
      nil -> %{}
      comment -> %{"comment" => comment}
    end
  end
end
