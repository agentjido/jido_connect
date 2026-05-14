defmodule Jido.Connect.Google.ServiceAccountTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{CredentialLease, Error}
  alias Jido.Connect.Google.{Connections, ServiceAccount}

  @scope "https://www.googleapis.com/auth/drive.metadata.readonly"

  setup {Req.Test, :verify_on_exit!}

  setup_all do
    private_key = :public_key.generate_key({:rsa, 2048, 65_537})

    private_key_pem =
      :RSAPrivateKey
      |> :public_key.pem_entry_encode(private_key)
      |> then(&:public_key.pem_encode([&1]))

    pkcs8_private_key_pem =
      :PrivateKeyInfo
      |> :public_key.pem_entry_encode(private_key)
      |> then(&:public_key.pem_encode([&1]))

    {:ok,
     private_key: private_key,
     private_key_pem: private_key_pem,
     pkcs8_private_key_pem: pkcs8_private_key_pem}
  end

  setup do
    Application.put_env(:jido_connect_google, :google_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_google, :google_oauth_req_options)
    end)
  end

  test "builds signed JWT bearer assertions", %{private_key: private_key, private_key_pem: pem} do
    issued_at = ~U[2026-01-01 00:00:00Z]

    assert {:ok, jwt} =
             ServiceAccount.assertion(credentials(pem),
               scopes: [@scope],
               issued_at: issued_at,
               lifetime_seconds: 600,
               token_url: "https://oauth.test/token"
             )

    [header_segment, payload_segment, signature_segment] = String.split(jwt, ".")
    assert decode_segment(header_segment) == %{"alg" => "RS256", "kid" => "key-1", "typ" => "JWT"}

    assert decode_segment(payload_segment) == %{
             "aud" => "https://oauth.test/token",
             "exp" => DateTime.to_unix(issued_at) + 600,
             "iat" => DateTime.to_unix(issued_at),
             "iss" => "svc@example.iam.gserviceaccount.com",
             "scope" => @scope
           }

    signing_input = header_segment <> "." <> payload_segment
    signature = Base.url_decode64!(signature_segment, padding: false)
    assert :public_key.verify(signing_input, :sha256, signature, public_key(private_key))
  end

  test "includes delegated subjects for domain-wide delegation", %{private_key_pem: pem} do
    assert {:ok, jwt} =
             ServiceAccount.assertion(credentials(pem),
               scopes: [@scope],
               subject: "admin@example.com",
               issued_at: ~U[2026-01-01 00:00:00Z]
             )

    [_header, payload_segment, _signature] = String.split(jwt, ".")
    assert decode_segment(payload_segment)["sub"] == "admin@example.com"
  end

  test "accepts Google-style PKCS8 private keys", %{pkcs8_private_key_pem: pem} do
    assert String.starts_with?(pem, "-----BEGIN PRIVATE KEY-----")

    assert {:ok, jwt} =
             ServiceAccount.assertion(credentials(pem),
               scopes: [@scope],
               issued_at: ~U[2026-01-01 00:00:00Z]
             )

    assert [_header, _payload, _signature] = String.split(jwt, ".")
  end

  test "mints access tokens through Google's JWT bearer grant", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      params = URI.decode_query(body)

      assert params["grant_type"] == "urn:ietf:params:oauth:grant-type:jwt-bearer"

      assert decode_segment(params["assertion"] |> String.split(".") |> Enum.at(1))["scope"] ==
               @scope

      Req.Test.json(conn, %{
        access_token: "access",
        token_type: "Bearer",
        expires_in: 3600,
        scope: @scope
      })
    end)

    assert {:ok, token} =
             ServiceAccount.mint_token(credentials(pem),
               scopes: [@scope],
               issued_at: ~U[2026-01-01 00:00:00Z],
               token_url: "https://oauth.test/token"
             )

    assert token.access_token == "access"
    assert token.token_type == "Bearer"
    assert token.scope == [@scope]
    assert token.expires_at == ~U[2026-01-01 01:00:00Z]
  end

  test "builds service-account credential leases", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{access_token: "access", token_type: "Bearer", expires_in: 3600})
    end)

    {:ok, connection} =
      Connections.service_account_connection(
        %{"client_email" => "svc@example.iam.gserviceaccount.com"},
        tenant_id: "tenant_1",
        scopes: [@scope]
      )

    assert {:ok, %CredentialLease{} = lease} =
             ServiceAccount.credential_lease(connection, credentials(pem),
               issued_at: ~U[2026-01-01 00:00:00Z],
               token_url: "https://oauth.test/token"
             )

    assert lease.connection_id == connection.id
    assert lease.provider == :google
    assert lease.profile == :service_account
    assert lease.fields == %{access_token: "access"}
    assert lease.scopes == [@scope]
    assert lease.expires_at == ~U[2026-01-01 01:00:00Z]
    assert lease.metadata.credential_mode == :google_service_account_access_token
  end

  test "builds domain-delegated credential leases", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assertion = URI.decode_query(body)["assertion"]
      [_header, payload_segment, _signature] = String.split(assertion, ".")
      assert decode_segment(payload_segment)["sub"] == "admin@example.com"

      Req.Test.json(conn, %{access_token: "access", token_type: "Bearer", expires_in: 3600})
    end)

    {:ok, connection} =
      Connections.domain_delegated_service_account_connection(
        %{"client_email" => "svc@example.iam.gserviceaccount.com"},
        tenant_id: "tenant_1",
        subject: "admin@example.com",
        scopes: [@scope]
      )

    assert {:ok, %CredentialLease{} = lease} =
             ServiceAccount.credential_lease(connection, credentials(pem),
               issued_at: ~U[2026-01-01 00:00:00Z],
               token_url: "https://oauth.test/token"
             )

    assert lease.profile == :domain_delegated_service_account
    assert lease.metadata.credential_mode == :google_domain_delegated_access_token
    assert lease.metadata.delegated_subject == "admin@example.com"
  end

  test "rejects non-service-account connections", %{private_key_pem: pem} do
    {:ok, connection} =
      Connections.user_connection(
        %{"sub" => "123", "email" => "user@example.com"},
        tenant_id: "tenant_1",
        scopes: [@scope]
      )

    connection_id = connection.id

    assert {:error,
            %Error.AuthError{
              reason: :unsupported_auth_profile,
              connection_id: ^connection_id,
              details: %{
                profile: :user,
                allowed_profiles: [:service_account, :domain_delegated_service_account]
              }
            }} =
             ServiceAccount.credential_lease(connection, credentials(pem),
               token_url: "https://oauth.test/token"
             )
  end

  test "returns sanitized service-account errors", %{private_key_pem: pem} do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"error" => "invalid_grant", "error_description" => "bad jwt"})
    end)

    assert {:error, %Error.ProviderError{} = error} =
             ServiceAccount.mint_token(credentials(pem),
               scopes: [@scope],
               token_url: "https://oauth.test/token"
             )

    refute inspect(error) =~ pem
    refute inspect(error) =~ "assertion="
  end

  defp credentials(private_key_pem) do
    %{
      "client_email" => "svc@example.iam.gserviceaccount.com",
      "private_key" => private_key_pem,
      "private_key_id" => "key-1"
    }
  end

  defp decode_segment(segment) do
    segment
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  defp public_key(
         {:RSAPrivateKey, _version, modulus, public_exponent, _private_exponent, _prime1, _prime2,
          _exponent1, _exponent2, _coefficient, _other_prime_infos}
       ) do
    {:RSAPublicKey, modulus, public_exponent}
  end
end
