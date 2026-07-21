defmodule Jido.Connect.GitLab.ScopeResolver do
  @moduledoc """
  Resolves GitLab OAuth/PAT scopes.

  Each action maps to the narrowest set of GitLab API scopes required.
  The resolver is consulted by the `access` block at runtime.

  This is a shell implementation. Scope mappings will be populated as
  action fragments are added in subsequent waves.
  """

  @doc """
  Returns the least-privilege GitLab scopes for the given operation.
  """
  def required_scopes(_operation, _input, _connection), do: []
end
