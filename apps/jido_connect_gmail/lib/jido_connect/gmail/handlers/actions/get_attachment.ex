defmodule Jido.Connect.Gmail.Handlers.Actions.GetAttachment do
  @moduledoc false

  alias Jido.Connect.Gmail.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, attachment} <-
           client.get_attachment(input, Map.get(credentials, :access_token)) do
      {:ok,
       %{
         attachment:
           attachment
           |> public_map()
           |> Map.put_new(:message_id, Map.get(input, :message_id))
           |> Map.put_new(:attachment_id, Map.get(input, :attachment_id))
       }}
    end
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
