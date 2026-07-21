defmodule Jido.Connect.Calendly.ScopeResolver do
  @moduledoc """
  Resolves Calendly OAuth scopes.

  Calendly uses a small set of scopes (`view`, `edit`, `webhook`). The scaffold
  keeps scope behavior package-local so later action families can choose
  provider-specific least-privilege scopes.
  """

  def required_scopes(_operation, _input, _connection), do: []
end
