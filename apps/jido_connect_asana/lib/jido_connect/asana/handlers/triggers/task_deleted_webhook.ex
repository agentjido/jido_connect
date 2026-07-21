defmodule Jido.Connect.Asana.Handlers.Triggers.TaskDeletedWebhook do
  @moduledoc false

  alias Jido.Connect.Asana.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
