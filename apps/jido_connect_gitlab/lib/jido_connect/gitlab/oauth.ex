defmodule Jido.Connect.GitLab.OAuth do
  @moduledoc """
  GitLab OAuth2 helpers.

  Hosts own callback state, durable connection storage, and credential storage.
  This module only builds OAuth URLs and exchanges/revokes tokens.

  Supports GitLab.com and self-hosted GitLab instances by overriding
  `:base_url` in opts.
  """

  @default_authorize_url "https://gitlab.com/oauth/authorize"
  @default_token_url "https://gitlab.com/oauth/token"
  alias Jido.Connect.{Data, Error, Scope}
  alias Jido.Connect.OAuth, as: CoreOAuth

  @doc "Builds the GitLab authorization URL for the OAuth2 code flow."
  def authorize_url(opts) when is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITLAB_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)
    scope = opts |> Keyword.get(:scope, ["read_api"]) |> Scope.encode(separator: " ")

    authorize_url = Keyword.get(opts, :authorize_url, @default_authorize_url)

    CoreOAuth.authorize_url(authorize_url, %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      state: state,
      response_type: "code"
    })
  end

  @doc "Exchanges an authorization code for access and refresh tokens."
  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITLAB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITLAB_CLIENT_SECRET")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    token_url = Keyword.get(opts, :token_url, @default_token_url)

    CoreOAuth.req(
      base_url: token_url,
      headers: [{"accept", "application/json"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_gitlab, :gitlab_oauth_req_options, []))
    |> Req.post(
      json: %{
        grant_type: "authorization_code",
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri
      }
    )
    |> handle_token_response()
  end

  @doc "Refreshes an expired access token using a refresh token."
  def refresh_token(refresh_token, opts \\ [])
      when is_binary(refresh_token) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITLAB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITLAB_CLIENT_SECRET")
    token_url = Keyword.get(opts, :token_url, @default_token_url)

    CoreOAuth.req(
      base_url: token_url,
      headers: [{"accept", "application/json"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_gitlab, :gitlab_oauth_req_options, []))
    |> Req.post(
      json: %{
        grant_type: "refresh_token",
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token
      }
    )
    |> handle_token_response()
  end

  @doc """
  Revokes a GitLab OAuth access token.

  GitLab supports token revocation via the `/oauth/revoke` endpoint.
  """
  def revoke_token(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITLAB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITLAB_CLIENT_SECRET")
    token_url = Keyword.get(opts, :token_url, @default_token_url)

    CoreOAuth.req(
      base_url: String.replace(token_url, "/token", "/revoke"),
      headers: [{"accept", "application/json"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_gitlab, :gitlab_oauth_req_options, []))
    |> Req.post(
      json: %{
        client_id: client_id,
        client_secret: client_secret,
        token: access_token
      }
    )
    |> handle_revoke_response()
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    cond do
      error = Data.get(body, "error") ->
        {:error,
         Error.provider("GitLab OAuth token exchange failed",
           provider: :gitlab,
           reason: error,
           status: status,
           details: %{description: Data.get(body, "error_description"), body: body}
         )}

      access_token = Data.get(body, "access_token") ->
        {:ok,
         %{
           access_token: access_token,
           refresh_token: Data.get(body, "refresh_token"),
           token_type: Data.get(body, "token_type"),
           scope: body |> Data.get("scope", "") |> Scope.parse(),
           created_at: Data.get(body, "created_at")
         }}

      true ->
        invalid_success_response(body)
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error,
     Error.provider("GitLab OAuth token exchange failed",
       provider: :gitlab,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_token_response({:error, reason}) do
    {:error,
     Error.provider("GitLab OAuth token exchange failed",
       provider: :gitlab,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp handle_revoke_response({:ok, %{status: status}}) when status in 200..299 do
    :ok
  end

  defp handle_revoke_response({:ok, %{status: status, body: body}}) do
    {:error,
     Error.provider("GitLab OAuth token revocation failed",
       provider: :gitlab,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_revoke_response({:error, reason}) do
    {:error,
     Error.provider("GitLab OAuth token revocation failed",
       provider: :gitlab,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp error_message(%{"message" => msg}), do: msg
  defp error_message(%{"error_description" => desc}), do: desc
  defp error_message(body) when is_map(body), do: Data.get(body, "error", body)
  defp error_message(body), do: body

  defp invalid_success_response(body) do
    {:error,
     Error.provider("GitLab OAuth token exchange response was invalid",
       provider: :gitlab,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
