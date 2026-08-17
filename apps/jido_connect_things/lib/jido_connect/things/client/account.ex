defmodule Jido.Connect.Things.Client.Account do
  @moduledoc false
  @enforce_keys [:email, :status, :history_key, :issues]
  defstruct @enforce_keys
end
