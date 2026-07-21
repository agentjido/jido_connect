defmodule Jido.Connect.Calcom.Handlers.Actions.CreateWebhook do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, subscriber_url} <- require_subscriber_url(input),
         {:ok, triggers} <- require_triggers(input),
         {:ok, params} <- create_params(input, subscriber_url, triggers),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, webhook} <-
           client.create_webhook(params, ResourceHelpers.credential_token(credentials)) do
      {:ok, %{webhook: ResourceHelpers.public_map(webhook)}}
    end
  end

  defp require_subscriber_url(input) do
    case Data.get(input, :subscriber_url) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _other ->
        {:error,
         Error.validation("Cal.com webhook subscriber URL must be a non-empty string",
           reason: :invalid_subscriber_url,
           details: %{field: :subscriber_url}
         )}
    end
  end

  defp require_triggers(input) do
    case Data.get(input, :triggers) do
      [_ | _] = triggers ->
        {:ok, triggers}

      _other ->
        {:error,
         Error.validation("Cal.com webhook triggers must be a non-empty list",
           reason: :invalid_triggers,
           details: %{field: :triggers}
         )}
    end
  end

  defp create_params(input, subscriber_url, triggers) do
    params = %{subscriber_url: subscriber_url, triggers: triggers}

    params =
      case Data.get(input, :active) do
        nil -> params
        value -> Map.put(params, :active, value)
      end

    params =
      case Data.get(input, :payload_template) do
        nil -> params
        value -> Map.put(params, :payload_template, value)
      end

    params =
      case Data.get(input, :event_type_id) do
        nil -> params
        value -> Map.put(params, :event_type_id, value)
      end

    {:ok, params}
  end
end
