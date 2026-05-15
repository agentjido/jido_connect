ExUnit.start()

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree (e.g. when a
# sibling package's dep like jido_mcp has a compilation issue that
# prevents `mix test` from starting all apps).
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
