ExUnit.start()

defmodule Jido.Connect.Zendesk.MockClient do
  @moduledoc false

  # Placeholder mock client for scaffold.
  # Methods will be added when action handlers are implemented.
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
