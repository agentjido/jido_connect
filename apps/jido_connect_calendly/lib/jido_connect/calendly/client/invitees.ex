defmodule Jido.Connect.Calendly.Client.Invitees do
  @moduledoc "Calendly API v2 boundary for invitee reads and cancellation."

  alias Jido.Connect.Calendly.Client.{Response, Transport}
  alias Jido.Connect.Calendly.Normalizer

  @base_path "/scheduled_events"

  @doc "Lists Calendly invitees for a given scheduled event URI."
  def list_invitees(%{event_uri: event_uri} = params, access_token)
      when is_binary(event_uri) and is_binary(access_token) do
    event_uuid = extract_uuid(event_uri)

    access_token
    |> Transport.api_request()
    |> Req.get(
      url: "#{@base_path}/#{event_uuid}/invitees",
      params: build_list_params(params)
    )
    |> Response.handle_list_response(&Normalizer.invitee_list/1, "invitees")
  end

  @doc "Gets a single Calendly invitee by event URI and invitee URI."
  def get_invitee(%{event_uri: event_uri, uri: uri} = _params, access_token)
      when is_binary(event_uri) and is_binary(uri) and is_binary(access_token) do
    event_uuid = extract_uuid(event_uri)
    invitee_uuid = extract_uuid(uri)

    access_token
    |> Transport.api_request()
    |> Req.get(url: "#{@base_path}/#{event_uuid}/invitees/#{invitee_uuid}")
    |> Response.handle_entity_response(&Normalizer.invitee/1, "invitee")
  end

  @doc "Cancels a Calendly invitee by event URI and invitee URI with an optional reason."
  def cancel_invitee(%{event_uri: event_uri, uri: uri} = params, access_token)
      when is_binary(event_uri) and is_binary(uri) and is_binary(access_token) do
    event_uuid = extract_uuid(event_uri)
    invitee_uuid = extract_uuid(uri)

    body =
      case Map.get(params, :reason) do
        nil -> %{}
        reason -> %{reason: reason}
      end

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: "#{@base_path}/#{event_uuid}/invitees/#{invitee_uuid}/cancellation",
      json: body
    )
    |> Response.handle_entity_response(&Normalizer.invitee/1, "invitee")
  end

  defp build_list_params(params) do
    []
    |> maybe_put(:status, params[:status])
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
