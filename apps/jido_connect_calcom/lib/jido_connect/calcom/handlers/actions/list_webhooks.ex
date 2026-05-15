defmodule Jido.Connect.Calcom.Handlers.Actions.ListWebhooks do
  @moduledoc false

  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- list_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, webhooks} <-
           client.list_webhooks(params, ResourceHelpers.credential_token(credentials)) do
      {:ok,
       %{
         webhooks:
           webhooks
           |> Enum.map(&ResourceHelpers.public_map/1)
       }}
    end
  end

  defp list_input(input) do
    params =
      input
      |> Map.take([:event_type_id])
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    {:ok, params}
  end
end
