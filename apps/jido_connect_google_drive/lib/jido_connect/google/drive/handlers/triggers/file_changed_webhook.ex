defmodule Jido.Connect.Google.Drive.Handlers.Triggers.FileChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Webhook

  defdelegate normalize_signal(delivery), to: Webhook
  defdelegate normalize_channel_notification(headers, payload \\ nil), to: Webhook
end
