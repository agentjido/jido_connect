defmodule Jido.Connect.Things.PreparedWrite do
  @moduledoc "A secret-free Things provider plan paired with a core prepared action."

  alias Jido.Connect.{ExecutionSnapshot, PreparedAction}

  @enforce_keys [:action, :provider_plan, :integrity_hash]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          action: PreparedAction.t(),
          provider_plan: struct(),
          integrity_hash: String.t()
        }

  def new(%PreparedAction{} = action, provider_plan) when is_struct(provider_plan) do
    prepared = %__MODULE__{action: action, provider_plan: provider_plan, integrity_hash: ""}
    %{prepared | integrity_hash: integrity_hash(prepared)}
  end

  def valid?(%__MODULE__{} = prepared) do
    secure_compare(prepared.integrity_hash, integrity_hash(prepared))
  end

  def to_public_map(%__MODULE__{} = prepared) do
    %{
      action: PreparedAction.to_public_map(prepared.action),
      provider_plan: Jido.Connect.Things.Writer.Plan.to_public_map(prepared.provider_plan),
      integrity_hash: prepared.integrity_hash
    }
  end

  defp integrity_hash(%__MODULE__{} = prepared) do
    ExecutionSnapshot.hash({prepared.action, prepared.provider_plan})
  end

  defp secure_compare(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    :crypto.hash_equals(left, right)
  end

  defp secure_compare(_left, _right), do: false
end

defimpl Inspect, for: Jido.Connect.Things.PreparedWrite do
  import Inspect.Algebra

  def inspect(prepared, opts) do
    concat([
      "#Jido.Connect.Things.PreparedWrite<",
      to_doc(Jido.Connect.Things.PreparedWrite.to_public_map(prepared), opts),
      ">"
    ])
  end
end
