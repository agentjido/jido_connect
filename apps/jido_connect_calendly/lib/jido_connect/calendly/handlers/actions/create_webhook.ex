defmodule Jido.Connect.Calendly.Handlers.Actions.CreateWebhook do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, callback_url} <- require_callback_url(input),
         {:ok, events} <- require_events(input),
         {:ok, params} <- create_params(input, callback_url, events),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, webhook} <-
           client.create_webhook(params, ResourceHelpers.credential_token(credentials)) do
      {:ok, %{webhook: ResourceHelpers.public_map(webhook)}}
    end
  end

  defp require_callback_url(input) do
    case Data.get(input, :callback_url) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _other ->
        {:error,
         Error.validation("Calendly webhook callback URL must be a non-empty string",
           reason: :invalid_callback_url,
           details: %{field: :callback_url}
         )}
    end
  end

  defp require_events(input) do
    case Data.get(input, :events) do
      [_ | _] = events ->
        {:ok, events}

      _other ->
        {:error,
         Error.validation("Calendly webhook events must be a non-empty list",
           reason: :invalid_events,
           details: %{field: :events}
         )}
    end
  end

  defp create_params(input, callback_url, events) do
    params = %{callback_url: callback_url, events: events}

    params =
      case Data.get(input, :organization_uri) do
        nil -> params
        value -> Map.put(params, :organization_uri, value)
      end

    params =
      case Data.get(input, :user_uri) do
        nil -> params
        value -> Map.put(params, :user_uri, value)
      end

    params =
      case Data.get(input, :scope) do
        nil -> params
        value -> Map.put(params, :scope, value)
      end

    {:ok, params}
  end
end
