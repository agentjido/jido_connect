defmodule Jido.Connect.Nextcloud.OAuth do
  @moduledoc """
  Nextcloud OAuth2 helpers for hosts that explicitly opt into OAuth2.

  Nextcloud's built-in OAuth2 does not expose resource scopes. App-password
  auth remains the recommended profile for this package.
  """

  alias Jido.Connect.{Data, Error, OAuth}

  def authorize_url(opts) when is_list(opts) do
    base_url = opts |> Keyword.fetch!(:base_url) |> normalize_base_url()
    client_id = OAuth.fetch_required!(opts, :client_id, "NEXTCLOUD_CLIENT_ID")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    state = Keyword.fetch!(opts, :state)

    OAuth.authorize_url("#{base_url}/apps/oauth2/authorize", %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      response_type: "code"
    })
  end

  def exchange_code(code, opts \\ []) when is_binary(code) and is_list(opts) do
    base_url = opts |> Keyword.fetch!(:base_url) |> normalize_base_url()
    client_id = OAuth.fetch_required!(opts, :client_id, "NEXTCLOUD_CLIENT_ID")
    client_secret = OAuth.fetch_required!(opts, :client_secret, "NEXTCLOUD_CLIENT_SECRET")
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)

    OAuth.req(base_url: "#{base_url}/apps/oauth2/api/v1/token")
    |> Req.merge(Application.get_env(:jido_connect_nextcloud, :nextcloud_oauth_req_options, []))
    |> Req.post(
      form: %{
        grant_type: "authorization_code",
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri
      }
    )
    |> handle_token_response(base_url)
  end

  def refresh_token(refresh_token, opts \\ []) when is_binary(refresh_token) and is_list(opts) do
    base_url = opts |> Keyword.fetch!(:base_url) |> normalize_base_url()
    client_id = OAuth.fetch_required!(opts, :client_id, "NEXTCLOUD_CLIENT_ID")
    client_secret = OAuth.fetch_required!(opts, :client_secret, "NEXTCLOUD_CLIENT_SECRET")

    OAuth.req(base_url: "#{base_url}/apps/oauth2/api/v1/token")
    |> Req.merge(Application.get_env(:jido_connect_nextcloud, :nextcloud_oauth_req_options, []))
    |> Req.post(
      form: %{
        grant_type: "refresh_token",
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token
      }
    )
    |> handle_token_response(base_url)
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, base_url)
       when status in 200..299 do
    cond do
      error = Data.get(body, "error") ->
        {:error,
         Error.provider("Nextcloud OAuth token request failed",
           provider: :nextcloud,
           reason: error,
           status: status,
           details: %{description: Data.get(body, "error_description"), body: body}
         )}

      access_token = Data.get(body, "access_token") ->
        {:ok,
         %{
           base_url: base_url,
           access_token: access_token,
           refresh_token: Data.get(body, "refresh_token"),
           token_type: Data.get(body, "token_type"),
           expires_in: Data.get(body, "expires_in")
         }}

      true ->
        {:error,
         Error.provider("Nextcloud OAuth token response was invalid",
           provider: :nextcloud,
           reason: :invalid_response,
           status: status,
           details: %{body: body}
         )}
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, _base_url) do
    {:error,
     Error.provider("Nextcloud OAuth token request failed",
       provider: :nextcloud,
       reason: :http_error,
       status: status,
       details: %{body: body}
     )}
  end

  defp handle_token_response({:error, reason}, _base_url) do
    {:error,
     Error.provider("Nextcloud OAuth token request failed",
       provider: :nextcloud,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp normalize_base_url(base_url) do
    base_url
    |> String.trim()
    |> String.trim_trailing("/")
  end
end
