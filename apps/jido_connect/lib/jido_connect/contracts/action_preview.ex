defmodule Jido.Connect.ActionPreview do
  @moduledoc """
  Pure provider preview callback for an action.

  The callback receives parsed input and public action/connection metadata. It
  does not receive credentials or a credential lease.
  """

  @callback preview(input :: map(), context :: map()) ::
              map() | {:ok, map()} | {:error, term()}
end
