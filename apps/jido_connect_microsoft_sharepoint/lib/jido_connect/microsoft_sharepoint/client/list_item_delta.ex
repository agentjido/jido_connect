defmodule Jido.Connect.MicrosoftSharepoint.Client.ListItemDelta do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftSharepoint.{DeltaCursor, GraphPath, Normalizer, Query}

  def read(access_token, input) do
    with {:ok, resource_path} <- resource_path(input),
         {:ok, url, params} <- request_target(input, resource_path) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: params)
      |> normalize()
    end
  end

  defp request_target(input, resource_path) do
    case Map.get(input, :cursor) do
      nil ->
        with {:ok, params} <- Query.delta_params(input) do
          {:ok, resource_path, params}
        end

      cursor ->
        with {:ok, cursor} <- DeltaCursor.validate(cursor, resource_path) do
          {:ok, cursor, %{}}
        end
    end
  end

  defp resource_path(input) do
    GraphPath.resource_path([
      "sites",
      Map.get(input, :site_id),
      "lists",
      Map.get(input, :list_id),
      "items",
      "delta"
    ])
  end

  defp normalize({:ok, %{status: 200, body: body}}) when is_map(body) do
    case Normalizer.page(body, &Normalizer.list_item/1) do
      {:ok, %{items: items, next_link: next_link}} ->
        {:ok,
         %{
           items: items,
           next_link: next_link,
           delta_link: Data.get(body, "@odata.deltaLink")
         }}

      {:error, _reason} ->
        Transport.invalid_success_response("Failed to read SharePoint list item delta", body)
    end
  end

  defp normalize({:ok, response}) do
    Transport.handle_error_response({:ok, response},
      message: "Failed to read SharePoint list item delta"
    )
  end

  defp normalize({:error, _reason} = error) do
    Transport.handle_error_response(error, message: "Failed to read SharePoint list item delta")
  end
end
