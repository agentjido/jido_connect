defmodule Jido.Connect.Zendesk.Handlers.Actions.UpdateTicket do
  @moduledoc false

  alias Jido.Connect.Zendesk.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         attrs <- build_attrs(input),
         {:ok, ticket} <- client.update_ticket(input.ticket_id, attrs, token, []) do
      {:ok, ticket}
    end
  end

  defp fetch_client(%{zendesk_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp build_attrs(input) do
    fields = [
      :status,
      :priority,
      :type,
      :assignee_id,
      :group_id,
      :tags,
      :additional_tags,
      :remove_tags,
      :custom_fields
    ]

    Enum.reduce(fields, %{}, fn key, acc ->
      case Map.get(input, key) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end
end
