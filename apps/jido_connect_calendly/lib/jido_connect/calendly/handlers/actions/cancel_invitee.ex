defmodule Jido.Connect.Calendly.Handlers.Actions.CancelInvitee do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, event_uri} <- require_field(input, :event_uri, "event URI"),
         {:ok, uri} <- require_field(input, :uri, "invitee URI"),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, invitee} <-
           client.cancel_invitee(
             build_params(event_uri, uri, input),
             ResourceHelpers.credential_token(credentials)
           ) do
      {:ok, %{invitee: ResourceHelpers.public_map(invitee)}}
    end
  end

  defp require_field(input, field, label) do
    case Data.get(input, field) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _other ->
        {:error,
         Error.validation("Calendly #{label} must be a non-empty string",
           reason: :invalid_field,
           details: %{field: field}
         )}
    end
  end

  defp build_params(event_uri, uri, input) do
    base = %{event_uri: event_uri, uri: uri}

    case Data.get(input, :reason) do
      nil -> base
      reason -> Map.put(base, :reason, reason)
    end
  end
end
