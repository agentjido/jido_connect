ExUnit.start()

unless Code.ensure_loaded?(Jido.Connect.Microsoft.TestSupport.ConnectorContracts) do
  Code.require_file(
    "support/microsoft_connector_contracts.ex",
    __DIR__
  )
end
