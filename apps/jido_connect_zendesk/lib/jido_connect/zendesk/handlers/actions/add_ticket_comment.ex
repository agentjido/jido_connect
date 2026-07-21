defmodule Jido.Connect.Zendesk.Handlers.Actions.AddTicketComment do
  @moduledoc false

  alias Jido.Connect.Zendesk.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         comment_attrs <- build_comment_attrs(input),
         {:ok, comment} <- client.add_ticket_comment(input.ticket_id, comment_attrs, token, []) do
      {:ok, comment}
    end
  end

  defp fetch_client(%{zendesk_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp build_comment_attrs(input) do
    attrs = %{body: Map.get(input, :body, "")}

    attrs =
      case Map.get(input, :public) do
        nil -> attrs
        public? -> Map.put(attrs, :public, public?)
      end

    case Map.get(input, :author_id) do
      nil -> attrs
      author_id -> Map.put(attrs, :author_id, author_id)
    end
  end
end
