defmodule Jido.Connect.RuntimeControls do
  @moduledoc false

  @keys [:policy, :policy_context, :provider_client, :request_timeout_ms]

  def keys, do: @keys

  def from_context(context) when is_map(context), do: Map.take(context, @keys)
end
