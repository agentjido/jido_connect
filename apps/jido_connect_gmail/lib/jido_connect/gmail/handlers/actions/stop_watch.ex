defmodule Jido.Connect.Gmail.Handlers.Actions.StopWatch do
  @moduledoc false

  alias Jido.Connect.Gmail.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- client.stop_watch(input, Map.get(credentials, :access_token)) do
      {:ok, %{result: result}}
    end
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
