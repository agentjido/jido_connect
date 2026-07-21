defmodule Jido.Connect.Google.Forms.Client.Watches do
  @moduledoc "Google Forms watches API boundary."

  alias Jido.Connect.Google.Forms.Client.{Response, Transport}

  @event_types ~w(SCHEMA_RESPONSES)

  def create_watch(%{form_id: form_id, event_type: event_type} = params, access_token)
      when is_binary(form_id) and is_binary(event_type) and is_binary(access_token) do
    body = create_watch_body(params)

    access_token
    |> Transport.forms_request()
    |> Req.post(
      url: "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}/watches",
      json: body
    )
    |> Response.handle_watch_response()
  end

  def renew_watch(%{form_id: form_id, watch_id: watch_id} = params, access_token)
      when is_binary(form_id) and is_binary(watch_id) and is_binary(access_token) do
    body = renew_watch_body(params)

    access_token
    |> Transport.forms_request()
    |> Req.post(
      url:
        "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}/watches/#{URI.encode(watch_id, &URI.char_unreserved?/1)}:renew",
      json: body
    )
    |> Response.handle_watch_response()
  end

  def delete_watch(%{form_id: form_id, watch_id: watch_id}, access_token)
      when is_binary(form_id) and is_binary(watch_id) and is_binary(access_token) do
    access_token
    |> Transport.forms_request()
    |> Req.delete(
      url:
        "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}/watches/#{URI.encode(watch_id, &URI.char_unreserved?/1)}"
    )
    |> Response.handle_watch_delete_response()
  end

  def event_types, do: @event_types

  defp create_watch_body(params) do
    %{}
    |> put_required(:eventType, Map.get(params, :event_type))
    |> maybe_put(:target, Map.get(params, :target))
  end

  defp renew_watch_body(params) do
    %{}
    |> maybe_put(:target, Map.get(params, :target))
  end

  defp put_required(body, key, value) when is_binary(value), do: Map.put(body, key, value)
  defp put_required(body, _key, _value), do: body

  defp maybe_put(body, _key, nil), do: body
  defp maybe_put(body, key, value), do: Map.put(body, key, value)
end
