defmodule Jido.Connect.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Authorization, Connection, Context, CredentialLease, Error}

  defmodule AllowPolicy do
    def authorize(_operation, _input, _context, _connection, %{allow?: true}), do: :ok
    def authorize(_operation, _input, _context, _connection, _attrs), do: {:deny, :not_allowed}
  end

  defmodule RaisingPolicy do
    def authorize(_operation, _input, _context, _connection), do: raise("policy failed")
  end

  defmodule InvalidScopeResolver do
    def required_scopes(_operation, _input, _connection), do: :invalid
  end

  test "authorizes a connected operation with a matching active lease" do
    connection = connection()
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{access_token: "secret"},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert :ok = Authorization.authorize(operation(), %{repo: "org/repo"}, context, lease)
  end

  test "applies host policy after connection and lease validation" do
    connection = connection()
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{access_token: "secret"},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert :ok =
             Authorization.authorize(operation(), %{}, context, lease,
               policy: AllowPolicy,
               policy_context: %{allow?: true}
             )

    assert {:error,
            %Error.AuthError{
              reason: :policy_denied,
              connection_id: "conn_1",
              details: %{operation_id: "github.issue.list", reason: "not_allowed"}
            }} =
             Authorization.authorize(operation(), %{}, context, lease,
               policy: AllowPolicy,
               policy_context: %{allow?: false}
             )

    assert {:error,
            %Error.ExecutionError{
              phase: :policy,
              details: %{operation_id: "github.issue.list", message: "policy failed"}
            }} =
             Authorization.authorize(operation(), %{}, context, lease, policy: RaisingPolicy)
  end

  test "a declared policy fails closed when the host policy is absent" do
    connection = connection()
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{access_token: "secret"},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    required = operation(policies: [:admin_access], host_policy_required?: true)

    assert {:error,
            %Error.AuthError{
              reason: :policy_denied,
              details: %{operation_id: "github.issue.list", reason: "policy_required"}
            }} = Authorization.authorize(required, %{}, context, lease)

    assert :ok =
             Authorization.authorize(required, %{}, context, lease,
               policy: AllowPolicy,
               policy_context: %{allow?: true}
             )
  end

  test "lease scopes narrow durable connection scopes" do
    connection = connection(scopes: ["repo", "admin:org"])
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{},
        scopes: ["repo"],
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert :ok = Authorization.authorize(operation(scopes: ["repo"]), %{}, context, lease)

    assert {:error, %Error.AuthError{reason: :missing_scopes, missing_scopes: ["admin:org"]}} =
             Authorization.authorize(operation(scopes: ["admin:org"]), %{}, context, lease)
  end

  test "rejects connection and lease binding mismatches before provider execution" do
    connection = connection()
    context = context(connection)

    lease =
      CredentialLease.from_connection!(
        connection,
        %{},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert {:error, %Error.AuthError{reason: :credential_connection_mismatch}} =
             Authorization.authorize(operation(), %{}, context, %{lease | tenant_id: "other"})

    assert {:error, %Error.AuthError{reason: :credential_connection_mismatch}} =
             Authorization.authorize(operation(), %{}, context, %{lease | connection_id: "other"})
  end

  test "connection availability is lease-free and policy aware" do
    assert {:available, ["repo"]} =
             Authorization.connection_availability(operation(), connection(), %{})

    assert {:missing_scopes, ["repo"]} =
             Authorization.connection_availability(operation(), connection(scopes: []), %{})

    assert :connection_required =
             Authorization.connection_availability(operation(), connection(status: :revoked), %{})

    assert :connection_required =
             Authorization.connection_availability(
               operation(auth_profiles: [:installation]),
               connection(profile: :user),
               %{}
             )

    assert :disabled_by_policy =
             Authorization.connection_availability(operation(), connection(), %{},
               context: context(connection()),
               policy: AllowPolicy,
               policy_context: %{allow?: false}
             )

    assert {:configuration_error, %Error.ConfigError{key: :scope_resolver}} =
             Authorization.connection_availability(
               operation(scope_resolver: InvalidScopeResolver),
               connection(),
               %{}
             )
  end

  defp operation(attrs \\ []) do
    %{
      id: "github.issue.list",
      auth_profile: Keyword.get(attrs, :auth_profile, :user),
      auth_profiles: Keyword.get(attrs, :auth_profiles, [:user]),
      scopes: Keyword.get(attrs, :scopes, ["repo"]),
      policies: Keyword.get(attrs, :policies, []),
      host_policy_required?: Keyword.get(attrs, :host_policy_required?, false),
      scope_resolver: Keyword.get(attrs, :scope_resolver)
    }
  end

  defp context(connection) do
    Context.new!(%{
      tenant_id: connection.tenant_id,
      actor: %{id: connection.owner_id, type: connection.owner_type},
      connection: connection
    })
  end

  defp connection(attrs \\ []) do
    Connection.new!(%{
      id: Keyword.get(attrs, :id, "conn_1"),
      provider: Keyword.get(attrs, :provider, :github),
      profile: Keyword.get(attrs, :profile, :user),
      tenant_id: Keyword.get(attrs, :tenant_id, "tenant_1"),
      owner_type: Keyword.get(attrs, :owner_type, :user),
      owner_id: Keyword.get(attrs, :owner_id, "user_1"),
      status: Keyword.get(attrs, :status, :connected),
      scopes: Keyword.get(attrs, :scopes, ["repo"])
    })
  end
end
