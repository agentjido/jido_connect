defmodule Jido.Connect.Microsoft.ConnectionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Connection
  alias Jido.Connect.Microsoft.Connections

  test "builds user-level Microsoft OAuth connections" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_connection(
               %{
                 "id" => "aaa-bbb-ccc",
                 "mail" => "user@example.com",
                 "displayName" => "User Name",
                 "scope" => "openid email profile offline_access"
               },
               tenant_id: "tenant_1",
               credential_ref: "vault:microsoft:user:user@example.com"
             )

    assert connection.id == "microsoft-user-user@example.com"
    assert connection.provider == :microsoft
    assert connection.profile == :user
    assert connection.tenant_id == "tenant_1"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "user@example.com"
    assert connection.credential_ref == "vault:microsoft:user:user@example.com"
    assert connection.scopes == ["openid", "email", "profile", "offline_access"]
    assert connection.subject.microsoft_account_id == "aaa-bbb-ccc"
    assert connection.subject.email == "user@example.com"
    assert connection.metadata.mode == :microsoft_oauth
  end

  test "builds keyword user connections with explicit owner metadata" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_connection(
               tenant_id: "tenant_1",
               owner_id: :user_1,
               scopes: [:openid, :email],
               subject: %{workspace_id: "workspace_1"},
               metadata: %{source: :test}
             )

    assert connection.id == "microsoft-user-user_1"
    assert connection.owner_id == "user_1"
    assert connection.scopes == ["openid", "email"]
    assert connection.subject.workspace_id == "workspace_1"
    assert connection.metadata == %{mode: :microsoft_oauth, source: :test}
  end

  test "builds tenant-owned Microsoft application connections" do
    assert {:ok, %Connection{} = connection} =
             Connections.application_connection(
               tenant_id: "tenant_1",
               application_id: "app_1",
               credential_ref: "vault:microsoft:tenant_1:app_1",
               scopes: ["Sites.Selected"]
             )

    assert connection.id == "microsoft-application-tenant_1-app_1"
    assert connection.provider == :microsoft
    assert connection.profile == :application
    assert connection.owner_type == :tenant
    assert connection.owner_id == "tenant_1"
    assert connection.subject.microsoft_application_id == "app_1"
    assert connection.scopes == ["Sites.Selected"]
    assert connection.metadata.mode == :microsoft_client_credentials
  end

  test "raises when required connection inputs are missing" do
    assert_raise ArgumentError, ~r/Microsoft connection requires :tenant_id/, fn ->
      Connections.user_connection(%{}, [])
    end

    assert_raise ArgumentError, ~r/Microsoft user connection requires :owner_id/, fn ->
      Connections.user_connection(%{}, tenant_id: "tenant_1")
    end

    assert_raise ArgumentError,
                 ~r/Microsoft application connection requires :application_id/,
                 fn ->
                   Connections.application_connection(tenant_id: "tenant_1")
                 end
  end
end
