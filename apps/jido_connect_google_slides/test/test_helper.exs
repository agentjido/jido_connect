ExUnit.start()

unless Code.ensure_loaded?(Jido.Connect.Google.TestSupport.ConnectorContracts) do
  Code.require_file(
    "../../jido_connect_google/test/support/google_connector_contracts.ex",
    __DIR__
  )
end
