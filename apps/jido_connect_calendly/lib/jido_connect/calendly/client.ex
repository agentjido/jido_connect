defmodule Jido.Connect.Calendly.Client do
  @moduledoc "Calendly API client boundary."

  alias Jido.Connect.Calendly.Client.{EventTypes, Invitees, ScheduledEvents, WebhookSubscriptions}

  # Event types
  defdelegate list_event_types(params, access_token), to: EventTypes
  defdelegate get_event_type(params, access_token), to: EventTypes

  # Scheduled events
  defdelegate list_scheduled_events(params, access_token), to: ScheduledEvents
  defdelegate get_scheduled_event(params, access_token), to: ScheduledEvents

  # Invitees
  defdelegate list_invitees(params, access_token), to: Invitees
  defdelegate get_invitee(params, access_token), to: Invitees
  defdelegate cancel_invitee(params, access_token), to: Invitees

  # Webhook subscriptions
  defdelegate create_webhook(params, access_token), to: WebhookSubscriptions
  defdelegate list_webhooks(params, access_token), to: WebhookSubscriptions
  defdelegate delete_webhook(params, access_token), to: WebhookSubscriptions

  @doc """
  Returns the configured or injected client module.

  When a `:calendly_client` key is present in credentials (e.g., from a test
  lease), that module is used. Otherwise falls back to
  `Jido.Connect.Calendly.Client`.
  """
  def resolve(%{calendly_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
