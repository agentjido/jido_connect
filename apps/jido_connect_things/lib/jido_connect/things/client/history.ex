defmodule Jido.Connect.Things.Client.History do
  @moduledoc false
  @enforce_keys [:history_key, :head, :schema]
  defstruct @enforce_keys
end
