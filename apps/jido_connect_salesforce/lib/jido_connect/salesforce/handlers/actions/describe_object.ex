defmodule Jido.Connect.Salesforce.Handlers.Actions.DescribeObject do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, metadata} <- client.describe_object(input, credentials) do
      {:ok, %{metadata: ResourceHelpers.public_map(metadata)}}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
