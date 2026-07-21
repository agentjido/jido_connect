defmodule Jido.Connect.Calcom.Client.Webhooks do
  @moduledoc "Cal.com webhooks API boundary."

  alias Jido.Connect.Calcom.Client.{Response, Transport}

  def create_webhook(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:webhooks))
    |> Req.post(url: "/v2/webhooks", json: create_body(params))
    |> Response.handle_create_webhook_response()
  end

  def list_webhooks(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:webhooks))
    |> Req.get(url: "/v2/webhooks", params: list_params(params))
    |> Response.handle_list_webhooks_response()
  end

  def delete_webhook(%{webhook_id: webhook_id}, access_token)
      when is_integer(webhook_id) and is_binary(access_token) do
    access_token
    |> Transport.api_request(cal_api_version: Transport.api_version(:webhooks))
    |> Req.delete(url: "/v2/webhooks/#{webhook_id}")
    |> Response.handle_delete_webhook_response()
  end

  defp create_body(params) do
    params
    |> Map.take([
      :subscriber_url,
      :triggers,
      :active,
      :payload_template,
      :event_type_id,
      :secret
    ])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn
      {:subscriber_url, value} -> {"subscriberUrl", value}
      {:triggers, value} -> {"triggers", value}
      {:active, value} -> {"active", value}
      {:payload_template, value} -> {"payloadTemplate", value}
      {:event_type_id, value} -> {"eventTypeId", value}
      {:secret, value} -> {"secret", value}
    end)
  end

  defp list_params(params) do
    params
    |> Map.take([:event_type_id])
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new(fn
      {:event_type_id, value} -> {"eventTypeId", value}
    end)
  end
end
