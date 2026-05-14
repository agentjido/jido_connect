defmodule Jido.Connect.Google.ServiceAccount do
  @moduledoc """
  Google service-account JWT bearer helpers.

  Host applications still own durable credential storage. This module turns
  host-provided service-account credentials into a short-lived Google access
  token or a `Jido.Connect.CredentialLease`.
  """

  alias Jido.Connect.{Connection, CredentialLease, Data, Error, OAuth, Scope}
  alias Jido.Connect.Google.Scopes

  @token_url "https://oauth2.googleapis.com/token"
  @grant_type "urn:ietf:params:oauth:grant-type:jwt-bearer"
  @default_lifetime_seconds 3600

  @doc """
  Mints a Google access token with the JWT bearer grant.

  `credentials` accepts string or atom keys from a Google service-account JSON
  credential payload. Required fields are `client_email` and `private_key`.
  `private_key_id` is included as the JWT `kid` header when present.
  """
  @spec mint_token(map(), keyword()) :: {:ok, map()} | {:error, Error.error()}
  def mint_token(credentials, opts \\ []) when is_map(credentials) and is_list(opts) do
    with {:ok, assertion} <- assertion(credentials, opts) do
      token_request(opts)
      |> Req.post(
        form: %{
          grant_type: @grant_type,
          assertion: assertion
        }
      )
      |> handle_token_response("Google service account token mint failed", opts)
    end
  end

  @doc """
  Builds a signed JWT assertion for Google's JWT bearer grant.

  Pass `:scopes` or `:scope` as a list or space/comma-separated string. Pass
  `:subject` or include a `subject` credential field for Workspace domain-wide
  delegation.
  """
  @spec assertion(map(), keyword()) :: {:ok, String.t()} | {:error, Error.error()}
  def assertion(credentials, opts \\ []) when is_map(credentials) and is_list(opts) do
    with {:ok, client_email} <- required_credential(credentials, :client_email),
         {:ok, private_key_pem} <- required_credential(credentials, :private_key),
         {:ok, scopes} <- required_scopes(opts),
         {:ok, private_key} <- decode_private_key(private_key_pem),
         {:ok, header} <- jwt_header(credentials),
         {:ok, claims} <- jwt_claims(client_email, scopes, credentials, opts) do
      signing_input = encoded_json(header) <> "." <> encoded_json(claims)
      signature = private_key |> sign(signing_input) |> base64url()
      {:ok, signing_input <> "." <> signature}
    end
  end

  @doc """
  Mints a service-account token and wraps it in a Jido Connect credential lease.
  """
  @spec credential_lease(Connection.t(), map(), keyword()) ::
          {:ok, CredentialLease.t()} | {:error, term()}
  def credential_lease(%Connection{} = connection, credentials, opts \\ [])
      when is_map(credentials) and is_list(opts) do
    opts = connection_opts(connection, opts)

    with :ok <- require_service_account_connection(connection),
         {:ok, token} <- mint_token(credentials, opts),
         access_token when is_binary(access_token) <- Data.get(token, :access_token) do
      CredentialLease.from_connection(
        connection,
        %{access_token: access_token},
        issued_at: Keyword.get(opts, :issued_at),
        expires_at: Data.get(token, :expires_at),
        scopes: token_scopes(token, Keyword.fetch!(opts, :scopes)),
        metadata:
          %{
            token_type: Data.get(token, :token_type),
            credential_mode: credential_mode(connection.profile),
            delegated_subject: Keyword.get(opts, :subject)
          }
          |> Data.compact()
          |> Map.merge(Keyword.get(opts, :metadata, %{}))
      )
    else
      {:error, error} ->
        {:error, error}

      _missing ->
        {:error,
         Error.provider("Google service account token response was invalid",
           provider: :google,
           reason: :invalid_response,
           details: %{body: %{}}
         )}
    end
  end

  defp require_service_account_connection(%Connection{} = connection)
       when connection.profile in [:service_account, :domain_delegated_service_account],
       do: :ok

  defp require_service_account_connection(%Connection{} = connection) do
    {:error,
     Error.unsupported_auth_profile(connection.id, connection.profile, [
       :service_account,
       :domain_delegated_service_account
     ])}
  end

  defp connection_opts(%Connection{} = connection, opts) do
    scopes =
      opts
      |> Keyword.get(:scopes, Keyword.get(opts, :scope, connection.scopes))
      |> Scopes.normalize()

    subject =
      Keyword.get(opts, :subject) ||
        Data.get(connection.subject || %{}, :delegated_subject)

    opts = Keyword.put(opts, :scopes, scopes)

    if subject in [nil, ""],
      do: opts,
      else: Keyword.put(opts, :subject, subject)
  end

  defp jwt_header(credentials) do
    header =
      %{
        alg: "RS256",
        typ: "JWT",
        kid: optional_credential(credentials, :private_key_id)
      }
      |> Data.compact()

    {:ok, header}
  end

  defp jwt_claims(client_email, scopes, credentials, opts) do
    issued_at = opts |> Keyword.get(:issued_at, DateTime.utc_now()) |> unix_seconds()
    lifetime_seconds = Keyword.get(opts, :lifetime_seconds, @default_lifetime_seconds)
    subject = Keyword.get(opts, :subject) || optional_credential(credentials, :subject)

    claims =
      %{
        iss: client_email,
        scope: Scope.encode(scopes, separator: " "),
        aud: Keyword.get(opts, :audience, Keyword.get(opts, :token_url, @token_url)),
        iat: issued_at,
        exp: issued_at + lifetime_seconds,
        sub: subject
      }
      |> Data.compact()

    {:ok, claims}
  end

  defp required_credential(credentials, key) do
    case optional_credential(credentials, key) do
      value when is_binary(value) ->
        {:ok, value}

      _missing ->
        {:error,
         Error.provider("Google service account credential is missing #{key}",
           provider: :google,
           reason: :missing_credential,
           details: %{field: key}
         )}
    end
  end

  defp optional_credential(credentials, key) do
    case Data.get(credentials, key) do
      value when is_binary(value) ->
        value = String.trim(value)
        if value == "", do: nil, else: value

      value ->
        value
    end
  end

  defp required_scopes(opts) do
    scopes =
      opts
      |> Keyword.get(:scopes, Keyword.get(opts, :scope, []))
      |> Scopes.normalize()

    case scopes do
      [] ->
        {:error,
         Error.provider("Google service account scopes are required",
           provider: :google,
           reason: :missing_scopes
         )}

      scopes ->
        {:ok, scopes}
    end
  end

  defp decode_private_key(private_key_pem) do
    case :public_key.pem_decode(private_key_pem) do
      [] ->
        invalid_private_key()

      [entry | _rest] ->
        {:ok, :public_key.pem_entry_decode(entry)}
    end
  rescue
    _error -> invalid_private_key()
  end

  defp invalid_private_key do
    {:error,
     Error.provider("Google service account private key is invalid",
       provider: :google,
       reason: :invalid_private_key
     )}
  end

  defp sign(private_key, signing_input) do
    :public_key.sign(signing_input, :sha256, private_key)
  end

  defp encoded_json(value), do: value |> Jason.encode!() |> base64url()

  defp base64url(value), do: Base.url_encode64(value, padding: false)

  defp token_request(opts) do
    OAuth.req(
      base_url: Keyword.get(opts, :token_url, @token_url),
      headers: [{"content-type", "application/x-www-form-urlencoded"}]
    )
    |> Req.merge(Application.get_env(:jido_connect_google, :google_oauth_req_options, []))
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, message, opts)
       when status in 200..299 and is_map(body) do
    if error = Data.get(body, "error") do
      {:error,
       Error.provider(message,
         provider: :google,
         reason: error,
         status: status,
         details: %{description: Data.get(body, "error_description"), body: body}
       )}
    else
      normalize_token(body, opts)
    end
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, message, _opts) do
    {:error,
     Error.provider(message,
       provider: :google,
       reason: :http_error,
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  defp handle_token_response({:error, reason}, message, _opts) do
    {:error,
     Error.provider(message,
       provider: :google,
       reason: :request_error,
       details: %{reason: reason}
     )}
  end

  defp normalize_token(body, opts) do
    with access_token when is_binary(access_token) <- Data.get(body, "access_token") do
      issued_at = Keyword.get(opts, :issued_at, DateTime.utc_now())

      {:ok,
       %{
         access_token: access_token,
         token_type: Data.get(body, "token_type"),
         expires_in: Data.get(body, "expires_in"),
         expires_at: token_expires_at(body, issued_at),
         scope: body |> Data.get("scope") |> Scope.parse()
       }
       |> Data.compact()}
    else
      _other ->
        {:error,
         Error.provider("Google service account token response was invalid",
           provider: :google,
           reason: :invalid_response,
           details: %{body: body}
         )}
    end
  end

  defp token_expires_at(token, issued_at) do
    issued_at = date_time!(issued_at)

    case Data.get(token, "expires_in") do
      expires_in when is_integer(expires_in) ->
        DateTime.add(issued_at, expires_in, :second)

      expires_in when is_binary(expires_in) ->
        DateTime.add(issued_at, String.to_integer(expires_in), :second)

      _missing ->
        DateTime.add(issued_at, @default_lifetime_seconds, :second)
    end
  end

  defp token_scopes(token, fallback) do
    case Data.get(token, :scope) do
      scopes when scopes in [nil, []] -> fallback
      scopes when is_list(scopes) -> scopes
      scopes -> Scope.parse(scopes)
    end
  end

  defp credential_mode(:domain_delegated_service_account),
    do: :google_domain_delegated_access_token

  defp credential_mode(_profile), do: :google_service_account_access_token

  defp error_message(body) when is_map(body),
    do: Data.get(body, "error_description") || Data.get(body, "error", body)

  defp error_message(body) when is_binary(body),
    do: "provider returned #{byte_size(body)} byte body"

  defp error_message(_body), do: "provider returned an error response"

  defp unix_seconds(%DateTime{} = datetime), do: DateTime.to_unix(datetime)
  defp unix_seconds(seconds) when is_integer(seconds), do: seconds

  defp date_time!(%DateTime{} = datetime), do: datetime
  defp date_time!(seconds) when is_integer(seconds), do: DateTime.from_unix!(seconds)
end
