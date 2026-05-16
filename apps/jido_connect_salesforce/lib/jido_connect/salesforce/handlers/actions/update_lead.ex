defmodule Jido.Connect.Salesforce.Handlers.Actions.UpdateLead do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, _result} <- client.update_lead(input, credentials) do
      {:ok, %{lead_id: input.lead_id, success: true}}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
