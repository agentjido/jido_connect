defmodule Jido.Connect.Calcom.Client do
  @moduledoc "Cal.com API client boundary."

  alias Jido.Connect.Calcom.Client.{Bookings, EventTypes, Webhooks}

  defdelegate list_event_types(params, access_token), to: EventTypes
  defdelegate list_bookings(params, access_token), to: Bookings
  defdelegate get_booking(params, access_token), to: Bookings
  defdelegate cancel_booking(params, access_token), to: Bookings
  defdelegate reschedule_booking(params, access_token), to: Bookings
  defdelegate create_webhook(params, access_token), to: Webhooks
  defdelegate list_webhooks(params, access_token), to: Webhooks
  defdelegate delete_webhook(params, access_token), to: Webhooks
end
