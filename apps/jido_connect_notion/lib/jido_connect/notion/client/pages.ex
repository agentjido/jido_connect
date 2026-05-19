defmodule Jido.Connect.Notion.Client.Pages do
  @moduledoc "Notion page read API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec get_page(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_page(page_id, access_token)
      when is_binary(page_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/pages/#{URI.encode(page_id, &URI.char_unreserved?/1)}")
    |> Response.handle_page_response()
  end
end
