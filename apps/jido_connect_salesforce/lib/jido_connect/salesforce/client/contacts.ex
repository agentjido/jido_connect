defmodule Jido.Connect.Salesforce.Client.Contacts do
  @moduledoc "Salesforce REST API boundary for contact reads and writes."

  alias Jido.Connect.Salesforce.Client.{Params, Response, Transport}

  @doc "Gets a single Salesforce contact by ID."
  def get_contact(%{contact_id: contact_id} = _params, credentials)
      when is_binary(contact_id) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: "/sobjects/Contact/#{contact_id}")
    |> Response.handle_get_response(&normalize_contact/1)
  end

  @doc "Lists Salesforce contacts using SOQL query."
  def list_contacts(params, credentials) when is_map(params) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()
    soql = Params.contacts_soql(Keyword.new(params))

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: "/query", params: [q: soql])
    |> Response.handle_list_response(&normalize_contact/1)
  end

  @doc "Creates a new Salesforce contact."
  def create_contact(params, credentials) when is_map(params) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()
    body = Params.contact_write_body(params)

    instance_url
    |> Transport.api_request(access_token)
    |> Req.post(url: "/sobjects/Contact", json: body)
    |> handle_create_response()
  end

  @doc "Updates an existing Salesforce contact."
  def update_contact(%{contact_id: contact_id} = params, credentials)
      when is_binary(contact_id) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()
    body = Params.contact_write_body(params)

    instance_url
    |> Transport.api_request(access_token)
    |> Req.patch(url: "/sobjects/Contact/#{contact_id}", json: body)
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

  defp normalize_contact(payload) when is_map(payload) do
    {:ok,
     %{
       contact_id: payload["Id"],
       first_name: payload["FirstName"],
       last_name: payload["LastName"],
       email: payload["Email"],
       phone: payload["Phone"],
       title: payload["Title"],
       account_id: payload["AccountId"],
       created_at: payload["CreatedDate"],
       updated_at: payload["LastModifiedDate"],
       attributes: payload["attributes"]
     }
     |> Enum.reject(fn {_k, v} -> is_nil(v) end)
     |> Map.new()}
  end

  defp normalize_contact(_payload), do: {:error, :invalid_contact_payload}
end
