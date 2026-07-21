defmodule Jido.Connect.Microsoft.OAuth do
  @moduledoc """
  Microsoft OAuth helpers for host applications and Microsoft product packages.

  Hosts own callback state, durable connection storage, and refresh-token
  storage. This module builds Microsoft OAuth URLs, exchanges authorization
  codes, refreshes access tokens, and shapes short-lived credential leases.
  """

  alias Jido.Connect.{Connection, CredentialLease, Data, Error, OAuth, Scope}

  @authorize_url "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
  @token_url "https://login.microsoftonline.com/common/oauth2/v2.0/token"
  @default_scope ["openid", "email", "profile", "offline_access"]

  @doc "Builds a Microsoft OAuth authorization URL."
  @spec authorize_url(keyword()) :: String.t()
  def authorize_url(opts) when is_list(opts) do
    client_id = OAuth.fetch_required!(opts, :client_id, "MICROSOFT_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)
    scope = opts |> Keyword.get(:scope, @default_scope) |> Scope.encode(separator: " ")

    OAuth.authorize_url(Keyword.get(opts, :authorize_url, @authorize_url), %{
      client_id: client_id,
      code_challenge: Keyword.get(opts, :code_challenge),
      code_challenge_method: Keyword.get(opts, :code_challenge_method),
      login_hint: Keyword.get(opts, :login_hint),
      prompt: Keyword.get(opts, :prompt),
      redirect_uri: redirect_uri,
      response_mode: Keyword.get(opts, :response_mode),
      response_type: "code",
      scope: scope,
      state: state
    })
  end

  @doc "Exchanges an authorization code for a Microsoft OAuth token response."
  @spec exchange_code(String.t(), keyword()) :: {:ok, map()} | {:error, Error.error()}
  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = OAuth.fetch_required!(opts, :client_id, "MICROSOFT_CLIENT_ID")
    client_secret = OAuth.fetch_required!(opts, :client_secret, "MICROSOFT_CLIENT_SECRET")

    token_request(opts)
    |> Req.post(
      form: %{
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        grant_type: "authorization_code",
        redirect_uri: Keyword.get(opts, :redirect_uri),
        scope: opts |> Keyword.get(:scope) |> maybe_encode_scope()
      }
    )
    |> handle_token_response("Microsoft OAuth code exchange failed")
  end

  @doc "Refreshes a Microsoft OAuth access token from a durable refresh token."
  @spec refresh_token(String.t(), keyword()) :: {:ok, map()} | {:error, Error.error()}
  def refresh_token(refresh_token, opts \\ [])
      when is_binary(refresh_token) and is_list(opts) do
    client_id = OAuth.fetch_required!(opts, :client_id, "MICROSOFT_CLIENT_ID")
    client_secret = OAuth.fetch_required!(opts, :client_secret, "MICROSOFT_CLIENT_SECRET")

    token_request(opts)
    |> Req.post(
      form: %{
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        scope: opts |> Keyword.get(:scope) |> maybe_encode_scope()
      }
    )
    |> handle_token_response("Microsoft OAuth token refresh failed")
  end

  @doc "Builds a short-lived credential lease from a Microsoft token response."
  @spec credential_lease(Connection.t(), map(), keyword()) ::
          {:ok, CredentialLease.t()} | {:error, term()}
  def credential_lease(%Connection{} = connection, token, opts \\ [])
      when is_map(token) and is_list(opts) do
    with access_token when is_binary(access_token) <- Data.get(token, "access_token") do
      expires_at =
        Keyword.get(opts, :expires_at) ||
          token_expires_at(token, Keyword.get(opts, :issued_at, DateTime.utc_now()))

      CredentialLease.from_connection(
        connection,
        %{access_token: access_token},
        issued_at: Keyword.get(opts, :issued_at),
        expires_at: expires_at,
        scopes: Keyword.get(opts, :scopes, token_scopes(token, connection.scopes)),
        metadata:
          %{
            token_type: Data.get(token, "token_type"),
            credential_mode: :microsoft_oauth_access_token
          }
          |> Data.compact()
          |> Map.merge(Keyword.get(opts, :metadata, %{}))
      )
    else
      _missing ->
        {:error,
         Error.provider("Microsoft OAuth token response was invalid",
           provider: :microsoft,
           reason: :invalid_response,
           details: %{body: token}
         )}
    end
  end

  defp token_request(opts) do
    OAuth.req(
      base_url: Keyword.get(opts, :token_url, @token_url),
      headers: [{"content-type", "application/x-www-form-urlencoded"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_microsoft, :microsoft_oauth_req_options, []))
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, message)
       when status in 200..299 and is_map(body) do
    if error = Data.get(body, "error") do
      {:error,
       Error.provider(message,
         provider: :microsoft,
         reason: error,
         status: status,
         details: %{
           description: Data.get(body, "error_description"),
           body: body
         }
       )}
    else
      normalize_token(body)
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, message) do
    {:error,
     Error.provider(message,
       provider: :microsoft,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_token_response({:error, reason}, message) do
    {:error,
     Error.provider(message,
       provider: :microsoft,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp normalize_token(body) do
    with access_token when is_binary(access_token) <- Data.get(body, "access_token") do
      {:ok,
       %{
         access_token: access_token,
         refresh_token: Data.get(body, "refresh_token"),
         token_type: Data.get(body, "token_type"),
         expires_in: Data.get(body, "expires_in"),
         expires_at: token_expires_at(body, DateTime.utc_now()),
         scope: body |> Data.get("scope") |> Scope.parse()
       }
       |> Data.compact()}
    else
      _other ->
        {:error,
         Error.provider("Microsoft OAuth token response was invalid",
           provider: :microsoft,
           reason: :invalid_response,
           details: %{body: body}
         )}
    end
  end

  defp token_expires_at(token, issued_at) do
    case Data.get(token, "expires_in") do
      expires_in when is_integer(expires_in) ->
        DateTime.add(issued_at, expires_in, :second)

      expires_in when is_binary(expires_in) ->
        DateTime.add(issued_at, String.to_integer(expires_in), :second)

      _missing ->
        DateTime.add(issued_at, 3600, :second)
    end
  end

  defp token_scopes(token, fallback) do
    case Scope.parse(Data.get(token, "scope")) do
      [] -> fallback
      scopes -> scopes
    end
  end

  defp maybe_encode_scope(nil), do: nil
  defp maybe_encode_scope(scope), do: Scope.encode(scope, separator: " ")

  defp error_message(body) when is_map(body),
    do: Data.get(body, "error_description") || Data.get(body, "error", body)

  defp error_message(body) when is_binary(body),
    do: "provider returned #{byte_size(body)} byte body"

  defp error_message(_body), do: "provider returned an error response"
end
