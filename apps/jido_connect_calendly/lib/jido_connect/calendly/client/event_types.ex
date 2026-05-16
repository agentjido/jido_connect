defmodule Jido.Connect.Calendly.Client.EventTypes do
  @moduledoc "Calendly API v2 boundary for event type reads."

  alias Jido.Connect.Calendly.Client.{Response, Transport}
  alias Jido.Connect.Calendly.Normalizer

  @path "/event_types"

  @doc "Lists Calendly event types with optional user/organization scope and pagination."
  def list_event_types(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request()
    |> Req.get(url: @path, params: build_list_params(params))
    |> Response.handle_list_response(&Normalizer.event_type_list/1, "event_types")
  end

  @doc "Gets a single Calendly event type by URI."
  def get_event_type(%{uri: uri} = _params, access_token)
      when is_binary(uri) and is_binary(access_token) do
    uuid = extract_uuid(uri)

    access_token
    |> Transport.api_request()
    |> Req.get(url: "#{@path}/#{uuid}")
    |> Response.handle_entity_response(&Normalizer.event_type/1, "event_type")
  end

  defp build_list_params(params) do
    []
    |> maybe_put(:user, params[:user_uri])
    |> maybe_put(:organization, params[:organization_uri])
    |> maybe_put(:active, params[:active])
    |> maybe_put(:page_token, params[:page_token])
    |> maybe_put(:count, params[:count] || 20)
    |> maybe_put(:sort, params[:sort])
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  defp extract_uuid(uri) when is_binary(uri) do
    uri
    |> String.trim_trailing("/")
    |> String.split("/")
    |> List.last()
  end
end
