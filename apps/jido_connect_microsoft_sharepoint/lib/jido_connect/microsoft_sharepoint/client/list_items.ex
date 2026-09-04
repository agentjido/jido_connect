defmodule Jido.Connect.MicrosoftSharepoint.Client.ListItems do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftSharepoint.{GraphPath, Normalizer, Query}
  alias Jido.Connect.MicrosoftSharepoint.Client.Response

  def list(access_token, input) do
    with {:ok, url} <- items_url(input),
         {:ok, params} <- Query.item_params(input) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: params)
      |> Response.page(&Normalizer.list_item/1, :items, "Failed to list SharePoint list items")
    end
  end

  def get(access_token, input) do
    with {:ok, url} <-
           GraphPath.resource_path([
             "sites",
             Map.get(input, :site_id),
             "lists",
             Map.get(input, :list_id),
             "items",
             Map.get(input, :item_id)
           ]),
         {:ok, params} <-
           Query.item_params(Map.drop(input, [:filter_field, :filter_operator, :filter_value])) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: Map.drop(params, [:"$top", :"$skip"]))
      |> Response.single(&Normalizer.list_item/1, :item, "Failed to get SharePoint list item")
    end
  end

  def create(access_token, input) do
    with {:ok, url} <- items_url(input),
         {:ok, fields} <- Query.write_fields(Map.get(input, :fields)) do
      access_token
      |> Transport.request()
      |> Transport.request(:post, url: url, json: %{fields: fields})
      |> Response.single(
        &Normalizer.list_item/1,
        :item,
        "Failed to create SharePoint list item",
        [201]
      )
    end
  end

  def update(access_token, input) do
    with {:ok, url} <- item_url(input, true),
         {:ok, fields} <- Query.write_fields(Map.get(input, :fields)),
         {:ok, etag} <- Query.etag(Map.get(input, :etag)) do
      result =
        access_token
        |> Transport.request()
        |> Transport.request(:patch,
          url: url,
          headers: [{"if-match", etag}],
          json: fields
        )

      normalize_update(result, input, fields)
    end
  end

  def delete(access_token, input) do
    with {:ok, url} <- item_url(input, false),
         {:ok, etag} <- Query.etag(Map.get(input, :etag)) do
      result =
        access_token
        |> Transport.request()
        |> Transport.request(:delete,
          url: url,
          headers: [{"if-match", etag}]
        )

      case result do
        {:ok, %{status: 204}} ->
          {:ok, %{deleted: true, item_id: Map.get(input, :item_id)}}

        {:ok, response} ->
          Transport.handle_error_response({:ok, response},
            message: "Failed to delete SharePoint list item"
          )

        {:error, _reason} = error ->
          Transport.handle_error_response(error,
            message: "Failed to delete SharePoint list item"
          )
      end
    end
  end

  defp items_url(input) do
    GraphPath.resource_path([
      "sites",
      Map.get(input, :site_id),
      "lists",
      Map.get(input, :list_id),
      "items"
    ])
  end

  defp item_url(input, fields?) do
    segments = [
      "sites",
      Map.get(input, :site_id),
      "lists",
      Map.get(input, :list_id),
      "items",
      Map.get(input, :item_id)
    ]

    GraphPath.resource_path(if(fields?, do: segments ++ ["fields"], else: segments))
  end

  defp normalize_update({:ok, %{status: 200, body: body}}, input, sent_fields)
       when is_map(body) do
    fields =
      body
      |> Map.reject(fn {key, _value} -> String.starts_with?(to_string(key), "@odata.") end)
      |> then(&if(map_size(&1) == 0, do: sent_fields, else: &1))

    payload = %{
      "id" => Map.get(input, :item_id),
      "eTag" => Map.get(body, "@odata.etag", Map.get(input, :etag)),
      "fields" => fields
    }

    case Normalizer.list_item(payload) do
      {:ok, item} ->
        {:ok, %{item: item}}

      {:error, _reason} ->
        Transport.invalid_success_response("Failed to update SharePoint list item", body)
    end
  end

  defp normalize_update({:ok, response}, _input, _fields) do
    Transport.handle_error_response({:ok, response},
      message: "Failed to update SharePoint list item"
    )
  end

  defp normalize_update({:error, _reason} = error, _input, _fields) do
    Transport.handle_error_response(error, message: "Failed to update SharePoint list item")
  end
end
