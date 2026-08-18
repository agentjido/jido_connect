defmodule Jido.Connect.Slack.Handlers.Actions.ClearStatus do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(_input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <-
           client.clear_status(
             %{profile: %{status_text: "", status_emoji: "", status_expiration: 0}},
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{status: Data.get(result, :status, %{}), submitted: true}}
    end
  end
end
