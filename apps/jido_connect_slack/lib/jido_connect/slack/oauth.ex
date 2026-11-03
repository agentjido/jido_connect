defmodule Jido.Connect.Slack.OAuth do
  @moduledoc """
  Slack OAuth v2 helpers.

  Hosts own callback state, durable installation storage, and credential
  storage. This module only builds URLs, exchanges codes, and shapes credential
  leases.
  """

  alias Jido.Connect
  alias Jido.Connect.{Data, Error, Scope}
  alias Jido.Connect.OAuth, as: CoreOAuth
  alias Jido.Connect.Slack.Client

  @authorize_url "https://slack.com/oauth/v2/authorize"
  @token_url "https://slack.com/api/oauth.v2.access"

  @doc """
  Builds Slack's authorize URL.

  `:scopes` (or `:scope`) are the bot scopes and go to Slack as `scope`.
  `:user_scope` lists the scopes of a user token for the person who
  authorizes, such as `["channels:history", "groups:history", "im:history",
  "mpim:history"]`, and goes to Slack as `user_scope`. Without `:user_scope`,
  or with an empty list, the URL has no `user_scope`.
  """
  def authorize_url(opts) when is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "SLACK_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)

    scopes =
      opts
      |> Keyword.get(:scopes, Keyword.get(opts, :scope, default_scopes()))
      |> Scope.encode(separator: ",")

    CoreOAuth.authorize_url(@authorize_url, %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scopes,
      user_scope: opts |> Keyword.get(:user_scope) |> encode_scopes(),
      state: state
    })
  end

  defp encode_scopes(nil), do: nil
  defp encode_scopes(scopes), do: Scope.encode(scopes, separator: ",")

  @doc """
  Exchanges a callback code through Slack `oauth.v2.access`.

  The result keeps the bot credential at the top: `access_token`,
  `token_type`, `scope` (a list), `bot_user_id`, `app_id`, `team` and
  `enterprise`. When the flow asked for `user_scope`, `authed_user` holds the
  authorizing user's credential: `id`, `access_token`, `token_type` and
  `scope`, and with token rotation also `refresh_token`, `expires_in` and
  `expires_at`. Without a user token the result has no `authed_user`. A
  response with only a user token yields `app_id`, `team`, `enterprise` and
  `authed_user`, without the bot fields.

  The host stores both credentials; `bot_credential_lease/3` and
  `user_credential_lease/3` turn them into leases.
  """
  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "SLACK_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "SLACK_CLIENT_SECRET")

    CoreOAuth.req(
      base_url: Keyword.get(opts, :base_url, @token_url),
      auth: {:basic, "#{client_id}:#{client_secret}"},
      headers: [
        {"accept", "application/json"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_slack, :slack_oauth_req_options, []))
    |> Req.post(
      form: %{
        code: code,
        redirect_uri: Keyword.get(opts, :redirect_uri)
      }
    )
    |> handle_token_response()
  end

  @doc """
  Builds a short-lived lease of the bot token from an `exchange_code/2`
  result, for actions under the `:bot` profile. The result may also come
  back from the host's storage with string keys.

  Pass `:connection` to bind the lease to the host's bot connection; the
  lease then takes that connection's ID, tenant and owner. A connection of
  another provider returns an `AuthError` with reason
  `:credential_connection_mismatch`. A connection of another profile, or a
  `:profile` other than `:bot`, returns one with reason
  `:unsupported_auth_profile`, since the lease would carry the bot token
  under another profile.

  Returns an `AuthError` with reason `:missing_bot_credential` for a result
  without a bot token, such as one from a flow with only `user_scope`.
  """
  def bot_credential_lease(token, context, opts \\ []) when is_map(token) do
    case Data.get(token, :access_token) do
      access_token when is_binary(access_token) ->
        team_id = team_id(token)
        scopes = Data.get(token, :scope, [])

        credential_lease(access_token, context, opts, %{
          connection_id: "slack-team-#{team_id}",
          profile: :bot,
          owner_type: :tenant,
          owner_id: team_id,
          scopes: scopes,
          token_expires_at: nil,
          metadata: %{
            context: context,
            app_id: Data.get(token, :app_id),
            bot_user_id: Data.get(token, :bot_user_id),
            team: Data.get(token, :team),
            enterprise: Data.get(token, :enterprise),
            scopes: scopes
          }
        })

      _none ->
        {:error,
         Error.auth("Slack token response has no bot token", reason: :missing_bot_credential)}
    end
  end

  @doc """
  Builds a short-lived lease of the authorizing user's token from the
  `authed_user` of an `exchange_code/2` result, for actions under the
  `:user` profile, such as `slack.conversation.history` and
  `slack.thread.replies`.

  The lease carries the user token as `access_token`, never the refresh
  token. It is owned by the user (`owner_type: :user`, `owner_id` the Slack
  user ID), its scopes are the user token's, and it expires after an hour,
  or at `:expires_at`, but never after the token's own `expires_at`.

  The result may also come back from the host's storage as JSON: with atom
  or string keys, and the token's `expires_at` as a `DateTime` or an ISO
  8601 string with offset. An `expires_at` in any other form returns an
  `AuthError` with reason `:invalid_user_credential`.

  Pass `:connection` to bind the lease to the host's user connection; the
  lease then takes that connection's ID, tenant and owner. The connection's
  `owner_id` is the host's and is not compared with the Slack user ID. A
  connection of another provider returns an `AuthError` with reason
  `:credential_connection_mismatch`. A connection of another profile, or a
  `:profile` other than `:user`, returns one with reason
  `:unsupported_auth_profile`, since the lease would carry the user token
  under another profile.

  Returns an `AuthError` with reason `:missing_user_credential` when the
  result holds no user token, as after a flow without `user_scope`.
  """
  def user_credential_lease(token, context, opts \\ []) when is_map(token) do
    with {:ok, access_token, user_id, user} <- authed_user(token),
         {:ok, token_expires_at} <- token_expires_at(Data.get(user, :expires_at)) do
      team_id = team_id(token)
      scopes = Data.get(user, :scope, [])

      credential_lease(access_token, context, opts, %{
        connection_id: "slack-team-#{team_id}-user-#{user_id}",
        profile: :user,
        owner_type: :user,
        owner_id: user_id,
        scopes: scopes,
        token_expires_at: token_expires_at,
        metadata: %{
          context: context,
          app_id: Data.get(token, :app_id),
          user_id: user_id,
          team: Data.get(token, :team),
          enterprise: Data.get(token, :enterprise),
          scopes: scopes
        }
      })
    end
  end

  defp authed_user(token) do
    with %{} = user <- Data.get(token, :authed_user),
         access_token when is_binary(access_token) <- Data.get(user, :access_token),
         user_id when is_binary(user_id) <- Data.get(user, :id) do
      {:ok, access_token, user_id, user}
    else
      _none ->
        {:error,
         Error.auth("Slack token response has no user token", reason: :missing_user_credential)}
    end
  end

  # `exchange_code/2` gives a DateTime. A host that stores the result as
  # JSON reads it back as an ISO 8601 string.
  defp token_expires_at(nil), do: {:ok, nil}
  defp token_expires_at(%DateTime{} = expires_at), do: {:ok, expires_at}

  defp token_expires_at(expires_at) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> invalid_token_expires_at()
    end
  end

  defp token_expires_at(_other), do: invalid_token_expires_at()

  defp invalid_token_expires_at do
    {:error,
     Error.auth("Slack user token has an unreadable expires_at",
       reason: :invalid_user_credential,
       details: %{field: :expires_at}
     )}
  end

  # A lease bound to `:connection` takes that connection's ID unless
  # `:connection_id` names another.
  defp credential_lease(access_token, context, opts, defaults) do
    expires_at =
      not_after(
        Keyword.get(opts, :expires_at) || DateTime.add(DateTime.utc_now(), 3600, :second),
        defaults.token_expires_at
      )

    fields = %{
      access_token: access_token,
      slack_client: Keyword.get(opts, :slack_client, Client)
    }

    case Keyword.get(opts, :connection) do
      %Connect.Connection{} = connection ->
        connection_id = Keyword.get(opts, :connection_id) || connection.id

        with :ok <- slack_connection(connection, connection_id),
             :ok <- token_profile(connection.profile, connection.id, defaults.profile) do
          Connect.CredentialLease.from_connection(connection, fields,
            connection_id: connection_id,
            expires_at: expires_at,
            scopes: defaults.scopes,
            metadata: defaults.metadata
          )
        end

      _other ->
        connection_id = Keyword.get(opts, :connection_id) || defaults.connection_id
        profile = Keyword.get(opts, :profile) || defaults.profile

        with :ok <- token_profile(profile, connection_id, defaults.profile) do
          Connect.CredentialLease.new(%{
            connection_id: connection_id,
            provider: :slack,
            profile: profile,
            tenant_id: Data.get(context, :tenant_id),
            owner_type: Keyword.get(opts, :owner_type, defaults.owner_type),
            owner_id: Keyword.get(opts, :owner_id) || defaults.owner_id,
            scopes: defaults.scopes,
            expires_at: expires_at,
            fields: fields,
            metadata: defaults.metadata
          })
        end
    end
  end

  # The details follow `CredentialLease.validate_connection_binding/2`:
  # `expected` is the connection's value, `actual` the lease's.
  defp slack_connection(%Connect.Connection{provider: :slack}, _connection_id), do: :ok

  defp slack_connection(%Connect.Connection{} = connection, connection_id) do
    {:error,
     Error.credential_connection_mismatch(connection.id, connection_id, %{
       field: :provider,
       expected: connection.provider,
       actual: :slack
     })}
  end

  # A bot token leases only under `:bot`, a user token only under `:user`.
  defp token_profile(profile, _connection_id, profile), do: :ok

  defp token_profile(profile, connection_id, token_profile),
    do: {:error, Error.unsupported_auth_profile(connection_id, profile, [token_profile])}

  defp not_after(expires_at, %DateTime{} = limit) do
    if DateTime.compare(expires_at, limit) == :gt, do: limit, else: expires_at
  end

  defp not_after(expires_at, _no_limit), do: expires_at

  defp team_id(token), do: token |> Data.get(:team) |> Data.get(:id)

  defp handle_token_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    case {bot_credential(body), user_credential(Data.get(body, "authed_user"))} do
      {nil, nil} ->
        invalid_success_response(body)

      {bot, user} ->
        {:ok,
         %{
           app_id: Data.get(body, "app_id"),
           team: Data.get(body, "team") || %{},
           enterprise: Data.get(body, "enterprise")
         }
         |> Map.merge(bot || %{})
         |> maybe_put(:authed_user, user)}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: %{"ok" => false} = body}}) do
    {:error,
     Error.provider("Slack OAuth exchange failed",
       provider: :slack,
       status: status,
       reason: Data.get(body, "error"),
       details: %{body: body}
     )}
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error,
     Error.provider("Slack OAuth HTTP request failed",
       provider: :slack,
       status: status,
       reason: :http_error,
       details: %{body: body}
     )}
  end

  defp handle_token_response({:error, reason}) do
    {:error,
     Error.provider("Slack OAuth request failed",
       provider: :slack,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  # The bot token sits at the top of the response. A response with only a
  # user token, such as Sign in with Slack or a flow with only `user_scope`,
  # has none.
  defp bot_credential(body) do
    with access_token when is_binary(access_token) <- Data.get(body, "access_token") do
      %{
        access_token: access_token,
        token_type: Data.get(body, "token_type"),
        scope: body |> Data.get("scope") |> Scope.parse(),
        bot_user_id: Data.get(body, "bot_user_id")
      }
    else
      _none -> nil
    end
  end

  # Slack puts the user token of the person who authorized under
  # `authed_user`, and only when the flow asked for `user_scope`. Without
  # it, `authed_user` holds the user ID alone and yields no credential.
  defp user_credential(%{} = authed_user) do
    with access_token when is_binary(access_token) <- Data.get(authed_user, "access_token") do
      Data.compact(%{
        id: Data.get(authed_user, "id"),
        access_token: access_token,
        token_type: Data.get(authed_user, "token_type"),
        scope: authed_user |> Data.get("scope") |> Scope.parse(),
        refresh_token: Data.get(authed_user, "refresh_token")
      })
      |> Map.merge(expiry(Data.get(authed_user, "expires_in")))
    else
      _none -> nil
    end
  end

  defp user_credential(_none), do: nil

  # With token rotation, a user token expires after `expires_in` seconds.
  defp expiry(seconds) when is_integer(seconds) and seconds > 0,
    do: %{expires_in: seconds, expires_at: DateTime.add(DateTime.utc_now(), seconds, :second)}

  defp expiry(_none), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp invalid_success_response(body) do
    {:error,
     Error.provider("Slack OAuth response was invalid",
       provider: :slack,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp default_scopes, do: ["channels:read", "chat:write", "reactions:write"]
end
