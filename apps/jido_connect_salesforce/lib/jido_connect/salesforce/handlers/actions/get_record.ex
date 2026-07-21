defmodule Jido.Connect.Salesforce.Handlers.Actions.GetRecord do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, record} <- client.get_record(input, credentials) do
      {:ok, %{record: ResourceHelpers.public_map(record)}}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
