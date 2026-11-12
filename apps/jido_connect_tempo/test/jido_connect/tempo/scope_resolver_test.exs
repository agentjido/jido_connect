defmodule Jido.Connect.Tempo.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Authorization, Connection, Error}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.{Fixture, ScopeResolver}

  @labels [
    "tempo.worklogs.read",
    "tempo.worklogs.write",
    "tempo.accounts.read",
    "tempo.periods.read",
    "tempo.approvals.read"
  ]

  test "both auth profiles carry exactly the resolver's labels" do
    assert ScopeResolver.labels() == @labels

    for profile <- Tempo.integration().auth_profiles do
      assert profile.scopes == @labels
    end
  end

  describe "granted_labels/1" do
    test "maps the recorded OAuth scope to all five labels" do
      for name <- ["oauth_exchange", "oauth_refresh"] do
        scope = Fixture.recorded!(name)["body"]["scope"]

        assert ScopeResolver.granted_labels(scope) == @labels
      end
    end

    test "maps each grant to one label and implies no other" do
      assert ScopeResolver.granted_labels("periods:view worklogs:view") == [
               "tempo.worklogs.read",
               "tempo.periods.read"
             ]

      assert ScopeResolver.granted_labels(["worklogs:manage"]) == ["tempo.worklogs.write"]

      assert ScopeResolver.granted_labels(["approvals:view", "accounts:view"]) == [
               "tempo.accounts.read",
               "tempo.approvals.read"
             ]
    end

    # The scope of Tempo's OpenAPI example token response is `read write`.
    test "maps the coarse read grant to the read labels and write to the worklog write label" do
      assert ScopeResolver.granted_labels("read") == [
               "tempo.worklogs.read",
               "tempo.accounts.read",
               "tempo.periods.read",
               "tempo.approvals.read"
             ]

      assert ScopeResolver.granted_labels("write") == ["tempo.worklogs.write"]
      assert ScopeResolver.granted_labels("read write") == @labels
    end

    test "ignores grants without a label" do
      assert ScopeResolver.granted_labels("teams:view accounts:manage activities:produce") == []
      assert ScopeResolver.granted_labels(nil) == []
    end
  end

  describe "required_scopes/3" do
    test "maps the own worklog read to the worklog read label only" do
      assert %{"tempo.worklogs.list_own" => ["tempo.worklogs.read"]} = ScopeResolver.operations()

      assert ScopeResolver.required_scopes(
               %{action_id: "tempo.worklogs.list_own"},
               %{},
               nil
             ) == ["tempo.worklogs.read"]
    end

    test "maps the period bookability read to the period and approval read labels" do
      assert %{
               "tempo.period.bookability.get" => ["tempo.periods.read", "tempo.approvals.read"]
             } = ScopeResolver.operations()

      assert ScopeResolver.required_scopes(
               %{action_id: "tempo.period.bookability.get"},
               %{},
               nil
             ) == ["tempo.periods.read", "tempo.approvals.read"]
    end

    # Tempo grants token rights per area and has no area for work
    # attributes; requiring the worklog read label is the connector's choice.
    test "maps the work attribute list to the worklog read label only" do
      assert ScopeResolver.required_scopes(
               %{action_id: "tempo.work_attribute.list"},
               %{},
               nil
             ) == ["tempo.worklogs.read"]
    end

    test "maps the account list for a project to the account read label only" do
      assert ScopeResolver.required_scopes(
               %{action_id: "tempo.account.list_for_project"},
               %{},
               nil
             ) == ["tempo.accounts.read"]
    end

    test "maps the worklog create to the worklog write label only" do
      assert ScopeResolver.operations() == %{
               "tempo.worklogs.list_own" => ["tempo.worklogs.read"],
               "tempo.worklog.create" => ["tempo.worklogs.write"],
               "tempo.period.bookability.get" => ["tempo.periods.read", "tempo.approvals.read"],
               "tempo.work_attribute.list" => ["tempo.worklogs.read"],
               "tempo.account.list_for_project" => ["tempo.accounts.read"]
             }

      assert ScopeResolver.required_scopes(%{action_id: "tempo.worklog.create"}, %{}, nil) ==
               ["tempo.worklogs.write"]
    end

    test "every declared Tempo action has an entry" do
      for action <- Tempo.integration().actions do
        assert Map.has_key?(ScopeResolver.operations(), action.id)
      end
    end

    test "an operation without an entry fails closed" do
      assert {:error, %Error.ConfigError{key: :scope_resolver, details: details}} =
               ScopeResolver.required_scopes(%{action_id: "tempo.unknown"}, %{}, nil)

      assert details.operation_id == "tempo.unknown"
    end

    test "the runtime reports an unmapped operation as a configuration error" do
      operation = %{
        action_id: "tempo.unknown",
        auth_profiles: [:api_token, :oauth2_user],
        scope_resolver: ScopeResolver
      }

      assert {:configuration_error, %Error.ConfigError{}} =
               Authorization.connection_availability(operation, connection(@labels))
    end
  end

  # The runtime checks `required -- connection.scopes`, so a label counts
  # only when the host recorded it, for OAuth through granted_labels/1.
  test "only labels recorded in connection.scopes satisfy a requirement" do
    operation = %{action_id: "tempo.example", auth_profiles: [:oauth2_user], scopes: @labels}
    scope = Fixture.recorded!("oauth_exchange")["body"]["scope"]

    assert {:available, @labels} =
             Authorization.connection_availability(
               operation,
               connection(ScopeResolver.granted_labels(scope))
             )

    assert {:missing_scopes, @labels} =
             Authorization.connection_availability(operation, connection(String.split(scope)))
  end

  test "a recorded scope of read write satisfies tempo.worklogs.write, read alone does not" do
    operation = %{
      action_id: "tempo.example",
      auth_profiles: [:oauth2_user],
      scopes: ["tempo.worklogs.write"]
    }

    assert {:available, ["tempo.worklogs.write"]} =
             Authorization.connection_availability(
               operation,
               connection(ScopeResolver.granted_labels("read write"))
             )

    assert {:missing_scopes, ["tempo.worklogs.write"]} =
             Authorization.connection_availability(
               operation,
               connection(ScopeResolver.granted_labels("read"))
             )
  end

  defp connection(scopes) do
    Connection.new!(%{
      id: "tempo_conn_1",
      provider: :tempo,
      profile: :oauth2_user,
      tenant_id: "tenant_1",
      owner_type: :app_user,
      owner_id: "user_1",
      subject: %{account_id: "712020:acct-a"},
      status: :connected,
      scopes: scopes,
      metadata: %{api_origin: "https://api.us.tempo.io"}
    })
  end
end
