defmodule Jido.Connect.Slack.TestSupport.LiveSlack do
  @moduledoc false

  # Shared by the Slack live smoke tests: runs Slack actions through
  # `Jido.Connect` with a connection and a credential lease around a live
  # token, records responses, and reads, posts and deletes messages with Req
  # outside the package as the reference.

  import ExUnit.Assertions

  alias Jido.Connect
  alias Jido.Connect.Slack.Client
  alias Jido.Connect.TestSupport.LiveSmoke

  @slack_api "https://slack.com/api"
  @req_options {:jido_connect_slack, :slack_req_options}

  @doc """
  Records the Slack responses of the current test under `name`.

  Each call starts the numbering again, so the next response goes to
  `name.json` and replaces what an earlier call under `name` wrote. `opts`
  are the sanitizer options of `LiveSmoke.record/4`.
  """
  def record(name, opts \\ []), do: LiveSmoke.record(@req_options, :slack, name, opts)

  @doc """
  Keeps the following responses of the current test out of the fixtures
  until the next `record/2`, for calls that no offline test replays.

  The recorder has no pause, so while recording these responses go to a
  scratch directory that is removed when the test exits.
  """
  def skip_recording do
    if LiveSmoke.recording?() do
      root = Path.join(System.tmp_dir!(), "jido_connect_slack_unrecorded")
      ExUnit.Callbacks.on_exit({__MODULE__, :scratch}, fn -> File.rm_rf!(root) end)
      LiveSmoke.record(@req_options, :slack, "unrecorded", root: root)
    end

    :ok
  end

  @doc """
  Invokes a Slack action under the `profile` connection with `scopes` on both
  the connection and the lease.

  The lease carries only the access token, so the action uses the package's
  default client.
  """
  def invoke(action_id, input, token, scopes, profile \\ :bot) do
    connection =
      Connect.Connection.new!(%{
        id: "slack-live-#{profile}",
        provider: :slack,
        profile: profile,
        tenant_id: "live-smoke",
        owner_type: if(profile == :user, do: :user, else: :tenant),
        owner_id: "live-smoke",
        status: :connected,
        scopes: scopes
      })

    Connect.invoke(Jido.Connect.Slack, action_id, input,
      context:
        Connect.Context.new!(%{
          tenant_id: "live-smoke",
          actor: %{id: "live-smoke", type: :user},
          connection: connection
        }),
      credential_lease:
        Connect.CredentialLease.new!(%{
          connection_id: connection.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          scopes: scopes,
          fields: %{access_token: token}
        })
    )
  end

  @doc "Returns the Slack user ID that `auth.test` names for `token`."
  def user_id!(token) do
    assert {:ok, %{"user_id" => user}} = Client.auth_test(token)
    user
  end

  @doc "Posts `payload` with `chat.postMessage` outside the package and returns its `ts`."
  def post_reference!(token, payload) do
    assert %{status: 200, body: %{"ok" => true, "ts" => ts}} =
             reference_request(token, :post, "chat.postMessage", json: payload)

    ts
  end

  @doc "Deletes the message `ts` in `channel` with `delete_message!/3` when the test exits."
  def delete_on_exit(token, channel, ts) do
    ExUnit.Callbacks.on_exit(fn -> delete_message!(token, channel, ts) end)
  end

  @doc """
  Deletes the message `ts` in `channel` with `chat.delete` outside the package.

  A message left behind changes the prepared conversations that the live
  checks count and moves the page boundaries of the next recording, so a
  failed delete fails the test. The failure names only the HTTP status and
  Slack's error code. A confirmed delete prints the message ID for the run's
  evidence.
  """
  def delete_message!(token, channel, ts) do
    case reference_request(token, :post, "chat.delete", json: %{channel: channel, ts: ts}) do
      %{status: 200, body: %{"ok" => true}} ->
        IO.puts("live_smoke slack: deleted post #{ts} in #{channel}")

      %{status: status, body: body} ->
        flunk(
          "chat.delete left the live test post #{ts} in #{channel}: " <>
            "HTTP #{status}, #{slack_error(body)}; delete it before the next live run"
        )
    end
  end

  @doc "Calls the Slack Web API directly, without the package's client and Req options."
  def reference_request(token, method, path, options) do
    [method: method, url: "#{@slack_api}/#{path}", auth: {:bearer, token}, retry: false]
    |> Keyword.merge(options)
    |> Req.request!()
  end

  defp slack_error(%{"error" => error}) when is_binary(error), do: error
  defp slack_error(_body), do: "no Slack error code"
end
