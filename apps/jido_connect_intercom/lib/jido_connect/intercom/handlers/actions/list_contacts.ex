defmodule Jido.Connect.Intercom.Handlers.Actions.ListContacts do
  @moduledoc false

  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_contacts(token,
             per_page: Map.get(input, :per_page),
             order: Map.get(input, :order),
             sort: Map.get(input, :sort),
             created_after: Map.get(input, :created_after),
             created_before: Map.get(input, :created_before)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
