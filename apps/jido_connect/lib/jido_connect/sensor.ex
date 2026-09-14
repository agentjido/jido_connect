defmodule Jido.Connect.Sensor do
  @moduledoc """
  Callback contract for generated Connect trigger adapters.

  The host owns scheduling, process supervision, and Signal delivery. Call
  `init/2` with trigger configuration and invocation context, then pass events
  to `handle_event/2`. Apply returned `{:schedule, milliseconds}` and
  `{:emit, signal}` instructions in the host. Polling retains its checkpoint
  in the returned state. Webhook adapters expose metadata only.

  This contract does not start a process. To use Jido v3 SensorManager, the
  host must supply an OTP process that drives these callbacks and resolves
  current credentials for each poll. Do not store leases in portable config.
  """

  @type instruction :: {:schedule, non_neg_integer()} | {:emit, Jido.Signal.t()}
  @type result :: {:ok, map()} | {:ok, map(), [instruction()]} | {:error, term()}

  @callback init(config :: map(), context :: map()) :: result()
  @callback handle_event(event :: term(), state :: map()) :: result()

  @doc """
  Replaces a generated poll sensor's invocation context without losing its checkpoint.

  The host can call this before each `:tick` with a current connection and a
  fresh credential lease. The host still owns scheduling and lease renewal.
  """
  @spec replace_context(map(), map()) :: map()
  def replace_context(%{context: _old, checkpoint: _checkpoint} = state, context)
      when is_map(context) do
    %{state | context: context}
  end
end
