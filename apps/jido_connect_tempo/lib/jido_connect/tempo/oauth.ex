defmodule Jido.Connect.Tempo.OAuth do
  @moduledoc """
  Tempo OAuth 2.0 helpers for the `:oauth2_user` profile.

  The host owns the callback route, its session binding, token storage and
  refresh scheduling. This module builds the authorize URL and posts the
  code exchange and the refresh to Tempo's token endpoint, as described in
  the Tempo REST v4 OpenAPI document (read 2026-10-30):

  - `authorize_url/1`: `https://api.tempo.io/oauth/authorize/redirect` with
    URL-encoded `client_id`, `redirect_uri` and `jira_url`.
  - `exchange_code/2` and `refresh/2`: form posts of `grant_type`,
    `client_id`, `client_secret`, `redirect_uri` and `code` or
    `refresh_token` to `https://api.tempo.io/oauth/token/`.

  Both return `access_token`, `refresh_token`, `expires_in` and `scope`, the
  granted Tempo scopes as a list. A refresh replaces both tokens: Tempo
  invalidates the old access and refresh token, so the host must store both
  new tokens before it uses either. A successful response that is not a
  JSON object, or lacks either token, is an `:invalid_response` error. Once
  Tempo has sent both tokens it has rotated the pair, so other fields do not
  discard them: `expires_in` is `nil` unless it is a positive integer, and
  the expiry is then unknown; `scope` is `nil` unless it is a string, and
  the host then keeps the labels it recorded before. The token response has
  no Atlassian account ID; the host records `connection.subject.account_id`
  from Jira `GET /rest/api/3/myself`.

  Rejections and transport failures are `Jido.Connect.Error.ProviderError`s
  normalized like API failures (Tempo rejects an invalid code or refresh
  token with 403). They never contain the client secret, the code or a
  token. Token requests do not follow redirects. Req options for tests come
  from `:tempo_oauth_req_options`.
  """

  alias Jido.Connect.{Error, Scope}
  alias Jido.Connect.OAuth, as: CoreOAuth
  alias Jido.Connect.Tempo.Client.Response

  @origin "https://api.tempo.io"
  @authorize_url @origin <> "/oauth/authorize/redirect"
  @token_path "/oauth/token/"
  # Req 0.7 still reads the legacy `follow_redirects` and `location_trusted`
  # before `redirect` and `redirect_trusted`, so they are dropped as well.
  @locked_options [
    :base_url,
    :url,
    :auth,
    :redirect,
    :redirect_trusted,
    :follow_redirects,
    :location_trusted
  ]
  @token_fields [access_token: "access_token", refresh_token: "refresh_token"]
  @request_failed "Tempo OAuth token request failed"

  @type token :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          expires_in: pos_integer() | nil,
          scope: [String.t()] | nil
        }

  @doc """
  Builds the Tempo authorize URL.

  Requires `:client_id`, `:redirect_uri` and `:jira_url`, the site URL such
  as `https://<site>.atlassian.net`. Raises `Jido.Connect.Error.ConfigError`
  for a missing or blank option.
  """
  @spec authorize_url(keyword()) :: String.t()
  def authorize_url(opts) when is_list(opts) do
    query =
      URI.encode_query(
        [
          client_id: required!(opts, :client_id),
          redirect_uri: required!(opts, :redirect_uri),
          jira_url: required!(opts, :jira_url)
        ],
        :rfc3986
      )

    @authorize_url <> "?" <> query
  end

  @doc """
  Exchanges an authorization code for an access and a refresh token.

  Requires `:client_id`, `:client_secret` and `:redirect_uri`.
  """
  @spec exchange_code(String.t(), keyword()) :: {:ok, token()} | {:error, Error.ProviderError.t()}
  def exchange_code(code, opts) when is_binary(code) and is_list(opts) do
    request_token([grant_type: "authorization_code", code: code], code, opts)
  end

  @doc """
  Exchanges a refresh token for a new access and refresh token.

  Requires `:client_id`, `:client_secret` and `:redirect_uri`.

  Treat the refresh token passed in as lost once Tempo may have seen the
  request: after any response from Tempo, and after an error with
  `delivery: :sent_outcome_unknown`, such as a timeout. A retry with that
  token cannot be relied on then, whatever `Jido.Connect.Error.retry_guidance/1`
  says; the host stores the new tokens or asks the user to authorize again.
  Only an error with `delivery: :not_sent`, such as a refused connection,
  leaves the token valid.
  """
  @spec refresh(String.t(), keyword()) :: {:ok, token()} | {:error, Error.ProviderError.t()}
  def refresh(refresh_token, opts) when is_binary(refresh_token) and is_list(opts) do
    request_token(
      [grant_type: "refresh_token", refresh_token: refresh_token],
      refresh_token,
      opts
    )
  end

  defp request_token([grant_type | grant], grant_secret, opts) do
    client_secret = required!(opts, :client_secret)

    form =
      [
        grant_type,
        client_id: required!(opts, :client_id),
        client_secret: client_secret,
        redirect_uri: required!(opts, :redirect_uri)
      ] ++ grant

    [base_url: @origin]
    |> CoreOAuth.req()
    |> Req.merge(req_options())
    |> Response.attach_json_decoder()
    |> Req.post(url: @token_path, form: form)
    |> token_response(message: @request_failed, redact: [client_secret, grant_secret])
  end

  defp req_options do
    [retry: false]
    |> Keyword.merge(Application.get_env(:jido_connect_tempo, :tempo_oauth_req_options, []))
    |> Keyword.drop(@locked_options)
    |> Keyword.put(:redirect, false)
  end

  # The secrets are redacted from Tempo's error text before the error keeps
  # its first 256 bytes, so a cut cannot leave a prefix.
  defp token_response({:ok, %{status: status}} = response, opts) do
    with {:ok, body} <- Response.handle(response, opts), do: token(body, status)
  end

  defp token_response(response, opts), do: Response.handle(response, opts)

  # Once Tempo answers with both tokens it has rotated the pair, so only a
  # missing token fails the response; an unusable expiry or scope is nil.
  defp token(%{} = body, status) do
    case for({field, key} <- @token_fields, not token?(body[key]), do: field) do
      [] ->
        {:ok,
         %{
           access_token: body["access_token"],
           refresh_token: body["refresh_token"],
           expires_in: expires_in(body["expires_in"]),
           scope: scope(body["scope"])
         }}

      missing ->
        Response.invalid_response("Tempo OAuth token response was invalid", nil,
          status: status,
          details: %{missing_fields: missing}
        )
    end
  end

  defp token(_body, status) do
    Response.invalid_response("Tempo OAuth token response was not a JSON object", nil,
      status: status
    )
  end

  defp token?(value), do: is_binary(value) and value != ""

  defp expires_in(seconds) when is_integer(seconds) and seconds > 0, do: seconds
  defp expires_in(_other), do: nil

  defp scope(scope) when is_binary(scope), do: Scope.parse(scope)
  defp scope(_other), do: nil

  defp required!(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" ->
        value

      _missing ->
        raise Error.config("Tempo OAuth requires #{key}", key: key)
    end
  end
end
