defmodule Jido.Connect.Slack.Handlers.Actions.AuthTest do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(_input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, auth} <- client.auth_test(Map.get(credentials, :access_token)) do
      {:ok, normalize_auth(auth)}
    end
  end

  defp normalize_auth(auth) do
    %{
      team_id: Data.get(auth, "team_id"),
      team: Data.get(auth, "team"),
      url: Data.get(auth, "url"),
      user_id: Data.get(auth, "user_id"),
      user: Data.get(auth, "user"),
      bot_id: Data.get(auth, "bot_id"),
      enterprise_id: Data.get(auth, "enterprise_id"),
      is_enterprise_install: Data.get(auth, "is_enterprise_install")
    }
    |> Data.compact()
  end
end
