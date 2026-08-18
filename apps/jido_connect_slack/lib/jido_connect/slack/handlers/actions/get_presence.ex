defmodule Jido.Connect.Slack.Handlers.Actions.GetPresence do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(_input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <- client.get_presence(Map.get(credentials, :access_token)) do
      {:ok,
       %{
         availability: Data.get(result, :availability, %{}),
         status: Data.get(result, :status, %{})
       }}
    end
  end
end
