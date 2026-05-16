defmodule Jido.Connect.Airtable.Client.Records do
  @moduledoc false

  alias Jido.Connect.Airtable.Client.{Response, Transport}

  @doc "Lists records from an Airtable table."
  def list_records(params, access_token) do
    base_id = Map.fetch!(params, :base_id)
    table_id = Map.fetch!(params, :table_id)

    query_params =
      params
      |> Map.take([:offset, :page_size, :max_records, :view, :fields, :filter_by_formula, :sort])
      |> maybe_put_fields()
      |> maybe_put_sort()
      |> maybe_put_filter()

    Transport.api_request(access_token)
    |> Req.merge(url: "/v0/#{base_id}/#{table_id}", params: query_params)
    |> Req.get()
    |> Response.handle_list_records_response()
  end

  @doc "Gets a single record from an Airtable table."
  def get_record(params, access_token) do
    base_id = Map.fetch!(params, :base_id)
    table_id = Map.fetch!(params, :table_id)
    record_id = Map.fetch!(params, :record_id)

    Transport.api_request(access_token)
    |> Req.merge(url: "/v0/#{base_id}/#{table_id}/#{record_id}")
    |> Req.get()
    |> Response.handle_get_record_response()
  end

  @doc "Creates a new record in an Airtable table."
  def create_record(params, access_token) do
    base_id = Map.fetch!(params, :base_id)
    table_id = Map.fetch!(params, :table_id)
    fields = Map.fetch!(params, :fields)
    typecast = Map.get(params, :typecast, false)

    Transport.api_request(access_token)
    |> Req.merge(
      url: "/v0/#{base_id}/#{table_id}",
      json: %{fields: fields, typecast: typecast}
    )
    |> Req.post()
    |> Response.handle_create_record_response()
  end

  @doc "Updates an existing record in an Airtable table."
  def update_record(params, access_token) do
    base_id = Map.fetch!(params, :base_id)
    table_id = Map.fetch!(params, :table_id)
    record_id = Map.fetch!(params, :record_id)
    fields = Map.fetch!(params, :fields)
    typecast = Map.get(params, :typecast, false)

    Transport.api_request(access_token)
    |> Req.merge(
      url: "/v0/#{base_id}/#{table_id}/#{record_id}",
      json: %{fields: fields, typecast: typecast}
    )
    |> Req.patch()
    |> Response.handle_update_record_response()
  end

  @doc "Deletes a record from an Airtable table."
  def delete_record(params, access_token) do
    base_id = Map.fetch!(params, :base_id)
    table_id = Map.fetch!(params, :table_id)
    record_id = Map.fetch!(params, :record_id)

    Transport.api_request(access_token)
    |> Req.merge(url: "/v0/#{base_id}/#{table_id}/#{record_id}")
    |> Req.delete()
    |> Response.handle_delete_record_response()
  end

  defp maybe_put_fields(%{fields: fields} = params) when is_list(fields) do
    params
    |> Map.delete(:fields)
    |> then(fn p ->
      Enum.reduce(fields, p, fn field, acc ->
        Map.update(acc, :field, [field], &[field | &1])
      end)
    end)
  end

  defp maybe_put_fields(params), do: params

  defp maybe_put_sort(%{sort: sort} = params) when is_list(sort) do
    sort_json = Jason.encode!(sort)
    params |> Map.delete(:sort) |> Map.put(:sort, sort_json)
  end

  defp maybe_put_sort(params), do: params

  defp maybe_put_filter(%{filter_by_formula: filter} = params) when is_binary(filter) do
    params |> Map.delete(:filter_by_formula) |> Map.put(:filterByFormula, filter)
  end

  defp maybe_put_filter(params), do: params
end
