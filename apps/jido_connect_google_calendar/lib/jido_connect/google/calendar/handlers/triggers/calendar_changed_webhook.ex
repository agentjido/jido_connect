defmodule Jido.Connect.Google.Calendar.Handlers.Triggers.CalendarChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Webhook

  defdelegate normalize_signal(delivery), to: Webhook
  defdelegate normalize_channel_notification(headers, payload \\ nil), to: Webhook
end
