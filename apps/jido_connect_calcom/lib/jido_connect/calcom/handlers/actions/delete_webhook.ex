defmodule Jido.Connect.Calcom.Handlers.Actions.DeleteWebhook do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, webhook_id} <- require_webhook_id(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, webhook} <-
           client.delete_webhook(
             %{webhook_id: webhook_id},
             ResourceHelpers.credential_token(credentials)
           ) do
      {:ok, %{webhook: ResourceHelpers.public_map(webhook)}}
    end
  end

  defp require_webhook_id(input) do
    case Data.get(input, :webhook_id) do
      value when is_integer(value) ->
        {:ok, value}

      _other ->
        {:error,
         Error.validation("Cal.com webhook ID must be an integer",
           reason: :invalid_webhook_id,
           details: %{field: :webhook_id}
         )}
    end
  end
end
