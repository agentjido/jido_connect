defmodule Jido.Connect.WebhookVerification do
  @moduledoc false

  def declared?(verification) when is_map(verification) do
    kinds = [Map.get(verification, :kind), Map.get(verification, "kind")]
    kinds = Enum.reject(kinds, &is_nil/1)

    kinds != [] and Enum.all?(kinds, &(&1 not in [:none, "none"]))
  end

  def declared?(_verification), do: false
end
