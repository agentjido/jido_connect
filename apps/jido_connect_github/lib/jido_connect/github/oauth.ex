defmodule Jido.Connect.GitHub.OAuth do
  @moduledoc """
  GitHub OAuth App helpers.

  Hosts own callback state, durable connection storage, and credential storage.
  This module builds OAuth URLs and handles code exchange, device authorization,
  token renewal, and revocation.
  """

  @authorize_url "https://github.com/login/oauth/authorize"
  @device_url "https://github.com/login/device/code"
  @token_url "https://github.com/login/oauth/access_token"
  @api_url "https://api.github.com"
  @setup_errors ~w(access_denied bad_refresh_token bad_verification_code device_flow_disabled expired_token incorrect_client_credentials incorrect_device_code unsupported_grant_type)

  alias Jido.Connect.{Data, Error, Scope}
  alias Jido.Connect.OAuth, as: CoreOAuth

  def authorize_url(opts) when is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)
    scope = opts |> Keyword.get(:scope, "read:user") |> Scope.encode(separator: " ")
    allow_signup = Keyword.get(opts, :allow_signup, true)
    challenge = Keyword.get(opts, :code_challenge)

    CoreOAuth.authorize_url(@authorize_url, %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      state: state,
      allow_signup: to_string(allow_signup),
      code_challenge: challenge,
      code_challenge_method: if(is_binary(challenge) and challenge != "", do: "S256")
    })
  end

  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    params = %{
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: Keyword.get(opts, :redirect_uri),
      state: Keyword.get(opts, :state)
    }

    params = put_token_value(params, :code_verifier, Keyword.get(opts, :code_verifier))

    CoreOAuth.req(
      base_url: Keyword.get(opts, :base_url, @token_url),
      headers: [
        {"accept", "application/json"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_oauth_req_options, []))
    |> Req.post(json: params, retry: false, redirect: false)
    |> handle_token_response()
  end

  @doc "Requests a device code and the user instructions for a headless OAuth flow."
  def start_device_authorization(opts) when is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    scope = opts |> Keyword.get(:scope, "read:user") |> Scope.encode(separator: " ")

    params = %{client_id: client_id, scope: scope}

    opts
    |> Keyword.get(:device_url, @device_url)
    |> oauth_post(params)
    |> handle_device_response()
  end

  @doc "Checks whether the user approved a device code. The host controls polling intervals."
  def poll_device_authorization(device_code, opts)
      when is_binary(device_code) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")

    params = %{
      client_id: client_id,
      device_code: device_code,
      grant_type: "urn:ietf:params:oauth:grant-type:device_code"
    }

    case oauth_post(Keyword.get(opts, :base_url, @token_url), params) do
      {:ok, %{status: status, body: %{"error" => reason}}}
      when (status in 200..299 or status == 400) and
             reason in ["authorization_pending", "slow_down"] ->
        {:pending, if(reason == "slow_down", do: :slow_down, else: :authorization_pending)}

      response ->
        handle_setup_response(response)
    end
  end

  @doc "Exchanges a refresh token for an updated token pair. The host must serialize refreshes."
  def refresh_token(refresh_token, opts) when is_binary(refresh_token) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    params = %{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    }

    opts
    |> Keyword.get(:base_url, @token_url)
    |> oauth_post(params)
    |> handle_setup_response()
  end

  def revoke_token(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    client_id = CoreOAuth.fetch_required!(opts, :client_id, "GITHUB_CLIENT_ID")
    client_secret = CoreOAuth.fetch_required!(opts, :client_secret, "GITHUB_CLIENT_SECRET")

    CoreOAuth.req(
      base_url: Keyword.get(opts, :api_base_url, @api_url),
      auth: {:basic, "#{client_id}:#{client_secret}"},
      headers: [
        {"accept", "application/vnd.github+json"}
      ]
    )
    |> Req.merge(Application.get_env(:jido_connect_github, :github_oauth_req_options, []))
    |> Req.delete(url: "/applications/#{client_id}/token", json: %{access_token: access_token})
    |> case do
      {:ok, %{status: status}} when status in 200..299 or status == 404 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error,
         Error.provider("GitHub OAuth token revocation failed",
           provider: :github,
           reason: :http_error,
           status: status,
           details: %{message: error_message(body), body: body}
         )}

      {:error, reason} ->
        {:error,
         Error.provider("GitHub OAuth token revocation failed",
           provider: :github,
           reason: :request_error,
           details: %{reason: reason}
         )}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    if error = Data.get(body, "error") do
      {:error,
       Error.provider("GitHub OAuth code exchange failed",
         provider: :github,
         reason: error,
         status: status,
         details: %{description: Data.get(body, "error_description"), body: body}
       )}
    else
      with access_token when is_binary(access_token) <- Data.get(body, "access_token") do
        {:ok,
         merge_token_lifetime(
           %{
             access_token: access_token,
             token_type: Data.get(body, "token_type"),
             scope: body |> Data.get("scope") |> Scope.parse()
           },
           body
         )}
      else
        _other ->
          invalid_success_response(body)
      end
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error,
     Error.provider("GitHub OAuth code exchange failed",
       provider: :github,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_token_response({:error, reason}) do
    {:error,
     Error.provider("GitHub OAuth code exchange failed",
       provider: :github,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp oauth_post(url, params) do
    CoreOAuth.req(base_url: url)
    |> Req.merge(Application.get_env(:jido_connect_github, :github_oauth_req_options, []))
    |> Req.post(form: params, retry: false, redirect: false)
  end

  defp handle_device_response({:ok, %{status: status, body: body}} = response)
       when status in 200..299 do
    with nil <- Data.get(body, "error"),
         code when is_binary(code) and byte_size(code) > 0 <- Data.get(body, "device_code"),
         user_code when is_binary(user_code) and byte_size(user_code) > 0 <-
           Data.get(body, "user_code"),
         uri when is_binary(uri) <- Data.get(body, "verification_uri"),
         %URI{scheme: "https", host: host, userinfo: nil} when is_binary(host) <- URI.parse(uri),
         expiry when is_integer(expiry) and expiry > 0 <- Data.get(body, "expires_in"),
         interval when is_integer(interval) and interval > 0 <- Data.get(body, "interval") do
      {:ok,
       %{
         device_code: code,
         user_code: user_code,
         verification_uri: uri,
         expires_in: expiry,
         interval: interval
       }}
    else
      _ ->
        if Data.get(body, "error"),
          do: handle_setup_response(response),
          else: invalid_success_response(body)
    end
  end

  defp handle_device_response(response), do: handle_setup_response(response)

  defp handle_setup_response({:ok, %{status: 400, body: %{"error" => reason}}})
       when reason in @setup_errors do
    {:error,
     Error.provider("GitHub OAuth request failed", provider: :github, reason: reason, status: 400)}
  end

  defp handle_setup_response(response) do
    case handle_token_response(response) do
      {:error, %Error.ProviderError{reason: reason, status: status}} ->
        reason =
          if reason in @setup_errors or reason in [:http_error, :request_error, :invalid_response],
            do: reason,
            else: :oauth_error

        {:error,
         Error.provider("GitHub OAuth request failed",
           provider: :github,
           reason: reason,
           status: status
         )}

      {:ok, _} = success ->
        success
    end
  end

  defp merge_token_lifetime(token, body) do
    token
    |> put_token_value(:refresh_token, Data.get(body, "refresh_token"))
    |> put_token_duration(:expires_in, Data.get(body, "expires_in"))
    |> put_token_duration(:refresh_token_expires_in, Data.get(body, "refresh_token_expires_in"))
  end

  defp put_token_value(params, key, value) when is_binary(value) and byte_size(value) > 0,
    do: Map.put(params, key, value)

  defp put_token_value(params, _key, _value), do: params

  defp put_token_duration(token, key, value) when is_integer(value) and value > 0,
    do: Map.put(token, key, value)

  defp put_token_duration(token, _key, _value), do: token

  defp error_message(body) when is_map(body), do: Data.get(body, "message", body)
  defp error_message(body), do: body

  defp invalid_success_response(body) do
    {:error,
     Error.provider("GitHub OAuth code exchange response was invalid",
       provider: :github,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
