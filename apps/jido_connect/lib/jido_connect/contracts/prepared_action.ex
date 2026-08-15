defmodule Jido.Connect.PreparedAction do
  @moduledoc """
  A secret-free snapshot of one authorized action before provider execution.

  The host must supply the input, context, credential lease, and binding again
  during commit. Jido Connect rejects the commit if one of their hashes changes.
  """

  @enforce_keys [
    :id,
    :integration_id,
    :action_id,
    :connection_id,
    :input_hash,
    :action_hash,
    :connection_hash,
    :lease_hash,
    :binding_hash,
    :risk,
    :confirmation,
    :confirmation_required?,
    :preview,
    :execution_id,
    :idempotency_key,
    :prepared_at,
    :expires_at
  ]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          integration_id: atom(),
          action_id: String.t(),
          connection_id: String.t(),
          input_hash: String.t(),
          action_hash: String.t(),
          connection_hash: String.t(),
          lease_hash: String.t(),
          binding_hash: String.t(),
          risk: atom(),
          confirmation: atom(),
          confirmation_required?: boolean(),
          preview: map(),
          execution_id: String.t() | nil,
          idempotency_key: String.t() | nil,
          prepared_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @doc "Returns true when the prepared action has expired."
  @spec expired?(t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{} = prepared, now \\ DateTime.utc_now()) do
    DateTime.compare(prepared.expires_at, now) != :gt
  end

  @doc "Returns the safe fields that a host can persist with its approval record."
  @spec to_public_map(t()) :: map()
  def to_public_map(%__MODULE__{} = prepared) do
    prepared
    |> Map.from_struct()
    |> Map.update!(:prepared_at, &DateTime.to_iso8601/1)
    |> Map.update!(:expires_at, &DateTime.to_iso8601/1)
  end
end
