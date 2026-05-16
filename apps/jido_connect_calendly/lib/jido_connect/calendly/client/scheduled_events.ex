defmodule Jido.Connect.Calendly.Client.ScheduledEvents do
  @moduledoc "Calendly API v2 boundary for scheduled event reads."

  alias Jido.Connect.Calendly.Client.{Response, Transport}
  alias Jido.Connect.Calendly.Normalizer

  @path "/scheduled_events"

  @doc "Lists Calendly scheduled events with optional user/organization scope, date filters, and pagination."
  def list_scheduled_events(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request()
    |> Req.get(url: @path, params: build_list_params(params))
    |> Response.handle_list_response(&Normalizer.scheduled_event_list/1, "scheduled_events")
  end

  @doc "Gets a single Calendly scheduled event by URI."
  def get_scheduled_event(%{uri: uri} = _params, access_token)
      when is_binary(uri) and is_binary(access_token) do
    uuid = extract_uuid(uri)

    access_token
    |> Transport.api_request()
    |> Req.get(url: "#{@path}/#{uuid}")
    |> Response.handle_entity_response(&Normalizer.scheduled_event/1, "scheduled_event")
  end

  defp build_list_params(params) do
    []
    |> maybe_put(:user, params[:user_uri])
    |> maybe_put(:organization, params[:organization_uri])
    |> maybe_put(:status, params[:status])
    |> maybe_put(:min_start_time, params[:min_start_time])
    |> maybe_put(:max_start_time, params[:max_start_time])
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
