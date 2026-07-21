defmodule Jido.Connect.Microsoft.Checkpoint do
  @moduledoc """
  Shared Microsoft Graph poll checkpoint error helpers.

  Microsoft Graph APIs use different checkpoint names and error statuses, but
  hosts should receive a stable reset hint whenever a checkpoint cannot be
  advanced safely.
  """

  alias Jido.Connect.{Data, Error}

  @reset_guidance %{
    action: :clear_checkpoint,
    behavior: :initialize_without_replay
  }

  @doc "Reset guidance hosts can surface when a Microsoft checkpoint expires or loops."
  @spec reset_guidance() :: map()
  def reset_guidance, do: @reset_guidance

  @doc "Returns a normalized expired-checkpoint provider error."
  @spec expired(String.t(), term(), Error.ProviderError.t(), keyword()) ::
          {:error, Error.ProviderError.t()}
  def expired(label, checkpoint, %Error.ProviderError{} = error, opts \\ []) do
    status = Keyword.get(opts, :status, error.status)

    {:error,
     Error.provider("#{label} checkpoint expired",
       provider: :microsoft,
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
       provider: :microsoft,
       reason: :invalid_response,
       details: Map.put(details, :checkpoint_reset, reset_guidance())
     )}
  end

  @doc "True when a Microsoft provider error means the stored checkpoint must be reset."
  @spec expired_provider_error?(Error.ProviderError.t()) :: boolean()
  def expired_provider_error?(%Error.ProviderError{reason: :checkpoint_expired}), do: true

  def expired_provider_error?(%Error.ProviderError{status: status}) when status in [404, 410],
    do: true

  def expired_provider_error?(%Error.ProviderError{}), do: false
end
