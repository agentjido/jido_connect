defmodule Jido.Connect.Calendly.Client.WebhookSubscriptions do
  @moduledoc "Calendly API v2 boundary for webhook subscription lifecycle."

  alias Jido.Connect.Calendly.Client.{Response, Transport}
  alias Jido.Connect.Calendly.Normalizer

  @path "/webhook_subscriptions"

  @doc "Creates a Calendly webhook subscription."
  def create_webhook(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request()
    |> Req.post(url: @path, json: build_create_body(params))
    |> Response.handle_entity_response(&Normalizer.webhook_subscription/1, "webhook_subscription")
  end

  @doc "Lists Calendly webhook subscriptions with optional organization/user scope."
  def list_webhooks(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request()
    |> Req.get(url: @path, params: build_list_params(params))
    |> Response.handle_list_response(
      &Normalizer.webhook_subscription_list/1,
      "webhook_subscriptions"
    )
  end

  @doc "Deletes a Calendly webhook subscription by URI."
  def delete_webhook(%{uri: uri} = _params, access_token)
      when is_binary(uri) and is_binary(access_token) do
    uuid = extract_uuid(uri)

    access_token
    |> Transport.api_request()
    |> Req.delete(url: "#{@path}/#{uuid}")
    |> Response.handle_delete_response("webhook_subscription")
  end

  defp build_create_body(params) do
    %{}
    |> maybe_put("url", params[:callback_url])
    |> maybe_put("events", params[:events])
    |> maybe_put("organization", params[:organization_uri])
    |> maybe_put("user", params[:user_uri])
    |> maybe_put("scope", params[:scope])
  end

  defp build_list_params(params) do
    []
    |> maybe_put(:organization, params[:organization_uri])
    |> maybe_put(:user, params[:user_uri])
    |> maybe_put(:page_token, params[:page_token])
    |> maybe_put(:count, params[:count] || 20)
    |> maybe_put(:sort, params[:sort])
  end

  defp maybe_put(map, _key, nil) when is_map(map), do: map
  defp maybe_put(map, key, value) when is_map(map), do: Map.put(map, key, value)

  defp maybe_put(list, _key, nil) when is_list(list), do: list
  defp maybe_put(list, key, value) when is_list(list), do: Keyword.put(list, key, value)

  defp extract_uuid(uri) when is_binary(uri) do
    uri
    |> String.trim_trailing("/")
    |> String.split("/")
    |> List.last()
  end
end
