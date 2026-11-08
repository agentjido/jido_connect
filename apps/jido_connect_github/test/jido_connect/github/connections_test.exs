defmodule Jido.Connect.GitHub.ConnectionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Connection
  alias Jido.Connect.GitHub.{Connections, ScopeResolver}

  test "builds user-level GitHub OAuth connections" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_connection(
               %{"login" => "octocat", "id" => 1, "scope" => "repo read:user"},
               tenant_id: "tenant_1",
               credential_ref: "vault:github:user:octocat"
             )

    assert connection.id == "github-user-octocat"
    assert connection.provider == :github
    assert connection.profile == :user
    assert connection.tenant_id == "tenant_1"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "octocat"
    assert connection.subject == %{github_login: "octocat", github_user_id: "1"}
    assert connection.credential_ref == "vault:github:user:octocat"
    assert connection.scopes == ["repo", "read:user"]
    assert connection.metadata.mode == :github_oauth
  end

  test "builds tenant-owned organization installation connections" do
    installation = %{
      "id" => 42,
      "account" => %{"login" => "acme", "id" => 99, "type" => "Organization"},
      "repository_selection" => "all",
      "permissions" => %{"metadata" => "read", "issues" => "write"}
    }

    assert {:ok, %Connection{} = connection} =
             Connections.installation_connection(installation, tenant_id: "tenant_1")

    assert connection.id == "github-installation-42"
    assert connection.profile == :installation
    assert connection.owner_type == :tenant
    assert connection.owner_id == "tenant_1"

    assert connection.subject == %{
             installation_id: "42",
             account_login: "acme",
             account_id: 99,
             account_type: "Organization"
           }

    assert connection.credential_ref == "github-app:42"
    assert connection.metadata.mode == :github_app
    assert connection.metadata.repository_selection == "all"
    assert connection.scopes == ["issues:read", "issues:write", "metadata:read"]
  end

  test "builds app-user-owned user account installation connections" do
    installation = %{
      id: "77",
      account: %{login: "octocat", type: "User"},
      repository_selection: "selected"
    }

    assert {:ok, %Connection{} = connection} =
             Connections.installation_connection(installation, tenant_id: "tenant_1")

    assert connection.id == "github-installation-77"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "octocat"
    assert connection.subject.account_type == "User"
    assert connection.subject.account_login == "octocat"
    assert connection.metadata.repository_selection == "selected"

    assert connection.scopes == [
             "actions:read",
             "actions:write",
             "metadata:read",
             "issues:read",
             "issues:write"
           ]
  end

  test "builds GitHub App user connections from exact fine-grained permissions" do
    assert {:ok, %Connection{} = connection} =
             Connections.github_app_user_connection(
               %{"login" => "octocat", "id" => 1},
               tenant_id: "tenant_1",
               permissions: %{"metadata" => "read", "contents" => "write"},
               metadata: %{installation_id: 42, repository: "acme/repo"}
             )

    assert connection.profile == :user
    assert connection.scopes == ["contents:read", "contents:write", "metadata:read"]
    assert connection.metadata.token_kind == :github_app_user
    assert connection.metadata.installation_id == 42
    refute "repo" in connection.scopes
  end

  test "adds an explicit public read capability without an OAuth repo scope" do
    assert {:ok, %Connection{} = connection} =
             Connections.github_app_user_connection(
               %{"login" => "octocat", "id" => 1},
               tenant_id: "tenant_1",
               metadata: %{public_read: true}
             )

    assert connection.scopes == ["public:read"]
    refute "repo" in connection.scopes
  end

  test "uses the explicit public read capability for public repository evidence" do
    connection = %{
      profile: :user,
      metadata: %{token_kind: :github_app_user, public_read: true}
    }

    for action_id <- [
          "github.issue.list",
          "github.pull_request.list",
          "github.check_run.list",
          "github.workflow_run.list",
          "github.commit.get",
          "github.git_tree.get",
          "github.git_blob.get"
        ] do
      assert ScopeResolver.required_scopes(
               %{id: action_id, scopes: ["repo"]},
               %{repo: "trust-arbor/arbor_mcp"},
               connection
             ) == ["public:read"]
    end
  end

  test "resolves GitHub App user scopes from the exact read operation" do
    connection = %{
      profile: :user,
      metadata: %{token_kind: :github_app_user, installation_id: 42}
    }

    assert ScopeResolver.required_scopes(
             %{id: "github.git_blob.get", scopes: ["repo"]},
             %{repo: "acme/repo"},
             connection
           ) == ["metadata:read", "contents:read"]

    assert ScopeResolver.required_scopes(
             %{id: "github.workflow_run.list", scopes: ["repo"]},
             %{repo: "acme/repo"},
             connection
           ) == ["metadata:read", "actions:read"]

    refute "repo" in ScopeResolver.required_scopes(
             %{id: "github.pull_request.list", scopes: ["repo"]},
             %{repo: "acme/repo"},
             connection
           )
  end

  test "does not grant a new connector action to a GitHub App user token" do
    connection = %{profile: :user, metadata: %{token_kind: :github_app_user}}

    assert ScopeResolver.required_scopes(
             %{id: "github.future.write", scopes: []},
             %{},
             connection
           ) == ["github_app_user:unsupported"]
  end

  test "lets hosts override installation ownership and ids" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_installation_connection(42,
               id: "conn_custom",
               tenant_id: "tenant_1",
               owner_id: "user_1",
               credential_ref: "vault:github:installation:42",
               scopes: ["metadata:read", "issues:read"],
               metadata: %{source: :test}
             )

    assert connection.id == "conn_custom"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "user_1"
    assert connection.credential_ref == "vault:github:installation:42"
    assert connection.scopes == ["metadata:read", "issues:read"]
    assert connection.metadata.source == :test
  end
end
