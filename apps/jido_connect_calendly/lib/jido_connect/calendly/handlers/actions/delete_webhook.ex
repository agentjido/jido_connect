defmodule Jido.Connect.Calendly.Handlers.Actions.DeleteWebhook do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, uri} <- require_uri(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.delete_webhook(
             %{uri: uri},
             ResourceHelpers.credential_token(credentials)
           ) do
      {:ok, %{webhook: ResourceHelpers.public_map(result)}}
    end
  end

  defp require_uri(input) do
    case Data.get(input, :uri) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _other ->
        {:error,
         Error.validation("Calendly webhook URI must be a non-empty string",
           reason: :invalid_webhook_uri,
           details: %{field: :uri}
         )}
    end
  end
end
