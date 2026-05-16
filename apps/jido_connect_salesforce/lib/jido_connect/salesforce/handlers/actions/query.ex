defmodule Jido.Connect.Salesforce.Handlers.Actions.Query do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, %{items: records, pagination: pagination}} <-
           client.query(input, credentials) do
      {:ok,
       %{
         records: ResourceHelpers.public_map(records),
         pagination: ResourceHelpers.public_map(pagination)
       }}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
