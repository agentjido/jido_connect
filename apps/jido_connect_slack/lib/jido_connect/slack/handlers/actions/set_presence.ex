defmodule Jido.Connect.Slack.Handlers.Actions.SetPresence do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    mode = Data.get(input, :mode)

    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, _result} <-
           client.set_presence(%{presence: mode}, Map.get(credentials, :access_token)) do
      {:ok, %{mode: mode, submitted: true}}
    end
  end
end
