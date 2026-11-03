defmodule Jido.Connect.Slack.Webhook.View do
  @moduledoc false

  # Whose view an Events API delivery comes from. Slack names one
  # installation that can see the event in `authorizations`: the bot's, with
  # `is_bot: true`, or the user token of a person who authorized the app,
  # with `is_bot: false`. Slack sends one event per workspace even when
  # several installations see it, and names only one of them; the full list
  # needs `apps.event.authorizations.list`.
  #
  # `view` is "bot" or "user" and `viewer` the `user_id` of that
  # authorization: the bot user or the authorizing person. A payload without
  # `authorizations`, or whose first entry has no boolean `is_bot`, has
  # neither field; a missing `user_id` drops only `viewer`.

  alias Jido.Connect.Data

  @views ["bot", "user"]

  @doc false
  def views, do: @views

  @doc false
  def from_payload(payload) do
    case Data.get(payload, "authorizations") do
      [%{} = authorization | _rest] -> from_authorization(authorization)
      _none -> %{}
    end
  end

  defp from_authorization(authorization) do
    case Data.get(authorization, "is_bot") do
      true -> view("bot", authorization)
      false -> view("user", authorization)
      _unknown -> %{}
    end
  end

  defp view(view, authorization) do
    case Data.get(authorization, "user_id") do
      viewer when is_binary(viewer) and viewer != "" -> %{view: view, viewer: viewer}
      _none -> %{view: view}
    end
  end
end
