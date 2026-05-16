defmodule Jido.Connect.Salesforce.Client.Objects do
  @moduledoc "Salesforce REST API boundary for generic SObject query and read operations."

  alias Jido.Connect.Salesforce.Client.{Response, Transport}
  alias Jido.Connect.Salesforce.Normalizer

  @default_list_fields ["Id", "Name", "LastModifiedDate", "CreatedDate"]
  @default_list_limit 100

  @doc "Executes a SOQL query and returns normalized records with pagination."
  def query(%{soql: soql} = _params, credentials)
      when is_binary(soql) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: "/query", params: [q: soql])
    |> Response.handle_list_response(&Normalizer.sobject_record/1)
  end

  @doc "Gets a single Salesforce record by SObject type and ID."
  def get_record(%{sobject_type: type, record_id: id} = params, credentials)
      when is_binary(type) and is_binary(id) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()

    query_params =
      case Map.get(params, :fields) do
        nil -> []
        fields when is_list(fields) -> [fields: Enum.join(fields, ",")]
      end

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: "/sobjects/#{type}/#{id}", params: query_params)
    |> Response.handle_get_response(&Normalizer.sobject_record/1)
  end

  @doc "Describes a Salesforce SObject's metadata."
  def describe_object(%{sobject_type: type} = _params, credentials)
      when is_binary(type) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: "/sobjects/#{type}/describe")
    |> handle_describe_response()
  end

  @doc "Lists recently modified records for a given SObject type using SOQL."
  def list_recent(%{sobject_type: type} = params, credentials)
      when is_binary(type) and is_map(credentials) do
    fields = Map.get(params, :fields, @default_list_fields)
    limit = Map.get(params, :limit, @default_list_limit)
    field_list = Enum.join(fields, ", ")

    soql = "SELECT #{field_list} FROM #{type} ORDER BY LastModifiedDate DESC LIMIT #{limit}"

    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: "/query", params: [q: soql])
    |> Response.handle_list_response(&Normalizer.sobject_record/1)
  end

  @doc "Fetches the next page of a paginated SOQL query result using nextRecordsUrl."
  def query_more(%{next_records_url: url} = _params, credentials)
      when is_binary(url) and is_map(credentials) do
    access_token = credentials[:access_token] || credentials[:api_key]
    instance_url = credentials[:instance_url] || Transport.default_instance_url()

    base = Transport.rest_base(instance_url)
    relative = String.replace_prefix(url, "/services/data/v#{Transport.api_version()}", "")

    instance_url
    |> Transport.api_request(access_token)
    |> Req.get(url: relative, base_url: base)
    |> Response.handle_list_response(&Normalizer.sobject_record/1)
  end

  defp handle_describe_response({:ok, %{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    case Normalizer.describe_metadata(body) do
      {:ok, metadata} ->
        {:ok, metadata}

      {:error, _error} ->
        Transport.invalid_success_response("Salesforce describe response was invalid", body)
    end
  end

  defp handle_describe_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    Transport.invalid_success_response("Salesforce describe response was invalid", body)
  end

  defp handle_describe_response(response), do: Transport.handle_error_response(response)
end
