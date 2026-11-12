ExUnit.start(exclude: [:live_smoke])

unless Code.ensure_loaded?(Jido.Connect.TestSupport.LiveSmoke) do
  Code.require_file("../../jido_connect/test/support/live_smoke.ex", __DIR__)
end

unless Code.ensure_loaded?(Jido.Connect.Google.TestSupport.ConnectorContracts) do
  Code.require_file(
    "../../jido_connect_google/test/support/google_connector_contracts.ex",
    __DIR__
  )
end
