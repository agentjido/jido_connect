defmodule Jido.Connect.Google.Calendar.Client.Acl do
  @moduledoc "Google Calendar ACL API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def list_acl(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl",
      params: Params.list_acl_params(params)
    )
    |> Response.handle_acl_list_response(params)
  end

  def get_acl(%{calendar_id: calendar_id, acl_rule_id: acl_rule_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(acl_rule_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl/#{encode_id(acl_rule_id)}",
      params: Params.get_acl_params(params)
    )
    |> Response.handle_acl_rule_response(params)
  end

  def create_acl(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl",
      params: Params.acl_mutation_params(params),
      json: Params.acl_rule_body(params)
    )
    |> Response.handle_acl_rule_response(params)
  end

  def patch_acl(%{calendar_id: calendar_id, acl_rule_id: acl_rule_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(acl_rule_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl/#{encode_id(acl_rule_id)}",
      params: Params.acl_mutation_params(params),
      json: Params.acl_rule_body(params)
    )
    |> Response.handle_acl_rule_response(params)
  end

  def update_acl(%{calendar_id: calendar_id, acl_rule_id: acl_rule_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(acl_rule_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl/#{encode_id(acl_rule_id)}",
      params: Params.acl_mutation_params(params),
      json: Params.acl_rule_body(params)
    )
    |> Response.handle_acl_rule_response(params)
  end

  def delete_acl(%{calendar_id: calendar_id, acl_rule_id: acl_rule_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(acl_rule_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/v3/calendars/#{encode_id(calendar_id)}/acl/#{encode_id(acl_rule_id)}")
    |> Response.handle_acl_delete_response(params)
  end

  def watch_acl(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl/watch",
      json: Params.watch_channel_body(params)
    )
    |> Response.handle_channel_response()
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
