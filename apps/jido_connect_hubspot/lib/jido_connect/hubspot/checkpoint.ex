defmodule Jido.Connect.HubSpot.Checkpoint do
  @moduledoc """
  Shared HubSpot poll checkpoint error helpers.

  HubSpot CRM objects use `lastmodifieddate` (ISO 8601 epoch-millis) as a
  polling checkpoint. Hosts should receive a stable reset hint whenever a
  checkpoint cannot be advanced safely.
  """

  alias Jido.Connect.{Data, Error}

  @reset_guidance %{
    action: :clear_checkpoint,
    behavior: :initialize_without_replay
  }

  @doc "Reset guidance hosts can surface when a HubSpot checkpoint is invalid."
  @spec reset_guidance() :: map()
  def reset_guidance, do: @reset_guidance

  @doc "Returns a normalized expired-checkpoint provider error."
  @spec expired(String.t(), term(), Error.ProviderError.t(), keyword()) ::
          {:error, Error.ProviderError.t()}
  def expired(label, checkpoint, %Error.ProviderError{} = error, opts \\ []) do
    status = Keyword.get(opts, :status, error.status)

    {:error,
     Error.provider("#{label} checkpoint expired",
       provider: :hubspot,
       reason: :checkpoint_expired,
       status: status,
       details:
         Data.compact(%{
           checkpoint: checkpoint,
           checkpoint_reset: reset_guidance(),
           provider_reason: error.reason,
           provider_details: error.details
         })
     )}
  end

  @doc "Returns a normalized invalid-checkpoint-response provider error."
  @spec invalid_response(String.t(), map()) :: {:error, Error.ProviderError.t()}
  def invalid_response(message, details \\ %{}) when is_map(details) do
    {:error,
     Error.provider(message,
       provider: :hubspot,
       reason: :invalid_response,
       details: Map.put(details, :checkpoint_reset, reset_guidance())
     )}
  end
end
