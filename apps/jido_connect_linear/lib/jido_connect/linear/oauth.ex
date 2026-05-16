defmodule Jido.Connect.Linear.OAuth do
  @moduledoc """
  Linear OAuth2 helpers.

  Hosts own callback state, durable connection storage, and credential storage.
  This module only builds OAuth URLs and exchanges tokens.
  """

  @authorize_url "https://linear.app/oauth/authorize"
  @token_url "https://api.linear.app/oauth/token"

  alias Jido.Connect.{Data, Error, Scope}
  alias Jido.Connect.OAuth, as: CoreOAuth

  @doc "Builds the Linear authorization URL for the OAuth2 code flow."
  def authorize_url(opts) when is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "LINEAR_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)
    scope = opts |> Keyword.get(:scope, ["read"]) |> Scope.encode(separator: " ")

    params = %{
      client_id: client_id,
      scope: scope,
      redirect_uri: redirect_uri,
      state: state,
      response_type: "code",
      prompt: "consent"
    }

    CoreOAuth.authorize_url(@authorize_url, params)
  end

  @doc "Exchanges an authorization code for access and refresh tokens."
  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "LINEAR_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "LINEAR_CLIENT_SECRET")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)

    CoreOAuth.req(
      base_url: Keyword.get(opts, :token_url, @token_url),
      headers: [{"accept", "application/json"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_linear, :linear_oauth_req_options, []))
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
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "LINEAR_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "LINEAR_CLIENT_SECRET")

    CoreOAuth.req(
      base_url: Keyword.get(opts, :token_url, @token_url),
      headers: [{"accept", "application/json"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_linear, :linear_oauth_req_options, []))
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

  defp handle_token_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    cond do
      error = Data.get(body, "error") ->
        {:error,
         Error.provider("Linear OAuth token exchange failed",
           provider: :linear,
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
           expires_in: Data.get(body, "expires_in")
         }}

      true ->
        invalid_success_response(body)
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error,
     Error.provider("Linear OAuth token exchange failed",
       provider: :linear,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_token_response({:error, reason}) do
    {:error,
     Error.provider("Linear OAuth token exchange failed",
       provider: :linear,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp error_message(%{"message" => msg}), do: msg
  defp error_message(body) when is_map(body), do: Data.get(body, "error_description", body)
  defp error_message(body), do: body

  defp invalid_success_response(body) do
    {:error,
     Error.provider("Linear OAuth token exchange response was invalid",
       provider: :linear,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
