defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListMessages do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftOutlook.Normalizer

  @doc """
  Lists messages from the authenticated user's mailbox.

  Supports:
  - `folder_id` (default: "inbox") - targets a specific mail folder
  - `query` - passes `$search` for full-text search via Graph query params
  - `page_size` (default: 25) - maps to `$top`
  - `skip` - maps to `$skip` for manual paging
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    folder_id = Map.get(input, :folder_id, "inbox")
    request = Transport.request(access_token)

    params =
      %{}
      |> Pagination.query(page_size: Map.get(input, :page_size, 25), skip: Map.get(input, :skip))
      |> maybe_search(Map.get(input, :query))

    url = "/me/mailFolders/#{folder_id}/messages"

    case Transport.request(request, :get, url: url, params: params) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Normalizer.page(body, &Normalizer.message/1) do
          {:ok, %{items: messages, next_link: next_link}} ->
            {:ok, %{messages: messages, next_link: next_link}}

          {:error, _reason} = error ->
            error
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to list Outlook messages"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: "Failed to list Outlook messages")
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp maybe_search(params, nil), do: params
  defp maybe_search(params, ""), do: params
  defp maybe_search(params, query), do: Map.put(params, :"$search", "\"#{query}\"")
end
