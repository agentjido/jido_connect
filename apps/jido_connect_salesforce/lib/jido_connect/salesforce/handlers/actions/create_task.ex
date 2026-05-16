defmodule Jido.Connect.Salesforce.Handlers.Actions.CreateTask do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, result} <- client.create_task(input, credentials) do
      {:ok, %{task_id: result.id, success: result.success}}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
