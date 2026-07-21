defmodule Jido.Connect.Salesforce.Client.Leads do
  @moduledoc "Salesforce REST API boundary for lead write operations."

  alias Jido.Connect.Salesforce.Client.{Params, Transport}

  @doc "Creates a new Salesforce lead."
  def create_lead(params, credentials) when is_map(params) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()
    body = Params.lead_write_body(params)

    instance_url
    |> Transport.api_request(access_token)
    |> Req.post(url: "/sobjects/Lead", json: body)
    |> handle_create_response()
  end

  @doc "Updates an existing Salesforce lead."
  def update_lead(%{lead_id: lead_id} = params, credentials)
      when is_binary(lead_id) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()
    body = Params.lead_write_body(params)

    instance_url
    |> Transport.api_request(access_token)
    |> Req.patch(url: "/sobjects/Lead/#{lead_id}", json: body)
    |> handle_update_response()
  end

  defp handle_create_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    case Map.get(body, "id") do
      nil ->
        Transport.invalid_success_response("Salesforce create response missing id", body)

      id ->
        {:ok,
         %{id: id, success: Map.get(body, "success", true), errors: Map.get(body, "errors", [])}}
    end
  end

  defp handle_create_response(response), do: Transport.handle_error_response(response)

  defp handle_update_response({:ok, %{status: status}})
       when status in 200..299 do
    {:ok, %{success: true}}
  end

  defp handle_update_response(response), do: Transport.handle_error_response(response)
end
