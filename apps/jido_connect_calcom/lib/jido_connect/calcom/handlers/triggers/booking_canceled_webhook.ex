defmodule Jido.Connect.Calcom.Handlers.Triggers.BookingCanceledWebhook do
  @moduledoc false

  alias Jido.Connect.Calcom.Webhook

  defdelegate normalize_signal(delivery), to: Webhook
  defdelegate verify_delivery(body, headers, webhook_secret, opts \\ []), to: Webhook
end
