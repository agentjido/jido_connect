defmodule Jido.Connect.Slack.Interactivity.Normalizer do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Interactivity.BlockActions

  # Dispatch hook for interactivity payload types. A type normalizer adds a
  # clause for its `type` above the fallback and receives the options given to
  # `Jido.Connect.Slack.Interactivity.verify_delivery/4` or
  # `normalize_signal/2`, such as app or callback IDs.
  @spec normalize_signal(String.t() | nil, map(), keyword()) ::
          {:ok, term()} | {:error, Error.ProviderError.t()}
  def normalize_signal("block_actions", payload, opts) do
    BlockActions.normalize_signal(payload, opts)
  end

  def normalize_signal(type, _payload, _opts) do
    {:error,
     Error.provider("Unsupported Slack interactivity payload type",
       provider: :slack,
       reason: :unsupported_event,
       details: %{type: type}
     )}
  end
end
