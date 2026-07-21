defmodule Jido.Connect.Asana.Handlers.Triggers.ProjectChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Asana.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
