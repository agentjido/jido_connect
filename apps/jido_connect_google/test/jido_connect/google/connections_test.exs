defmodule Jido.Connect.Google.ConnectionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Connection
  alias Jido.Connect.Google.Connections

  test "builds user-level Google OAuth connections" do
    assert {:ok, %Connection{} = connection} =
             Connections.user_connection(
               %{
                 "sub" => "123",
                 "email" => "user@example.com",
                 "scope" => "openid email profile"
               },
               tenant_id: "tenant_1",
               credential_ref: "vault:google:user:user@example.com"
             )

    assert connection.id == "google-user-user@example.com"
    assert connection.provider == :google
    assert connection.profile == :user
    assert connection.tenant_id == "tenant_1"
    assert connection.owner_type == :app_user
    assert connection.owner_id == "user@example.com"
    assert connection.credential_ref == "vault:google:user:user@example.com"
    assert connection.scopes == ["openid", "email", "profile"]
    assert connection.subject.google_account_id == "123"
    assert connection.subject.email == "user@example.com"
    assert connection.metadata.mode == :google_oauth
  end

  test "builds service account connection metadata" do
    assert {:ok, %Connection{} = connection} =
             Connections.service_account_connection(
               %{"client_email" => "svc@example.iam.gserviceaccount.com", "project_id" => "p1"},
               tenant_id: "tenant_1",
               scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"]
             )

    assert connection.provider == :google
    assert connection.profile == :service_account
    assert connection.owner_type == :system
    assert connection.subject.client_email == "svc@example.iam.gserviceaccount.com"
    assert connection.subject.project_id == "p1"
    assert connection.metadata.mode == :google_service_account
  end

  test "builds domain delegated service account connection metadata" do
    assert {:ok, %Connection{} = connection} =
             Connections.domain_delegated_service_account_connection(
               %{"client_email" => "svc@example.iam.gserviceaccount.com"},
               tenant_id: "tenant_1",
               subject: "admin@example.com"
             )

    assert connection.profile == :domain_delegated_service_account
    assert connection.owner_type == :tenant
    assert connection.owner_id == "tenant_1"
    assert connection.subject.delegated_subject == "admin@example.com"
    assert connection.metadata.mode == :google_domain_delegation
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

    assert connection.id == "google-user-user_1"
    assert connection.owner_id == "user_1"
    assert connection.scopes == ["openid", "email"]
    assert connection.subject.workspace_id == "workspace_1"
    assert connection.metadata == %{mode: :google_oauth, source: :test}
  end

  test "raises when required connection inputs are missing" do
    assert_raise ArgumentError, ~r/Google connection requires :tenant_id/, fn ->
      Connections.user_connection(%{}, [])
    end

    assert_raise ArgumentError, ~r/Google user connection requires :owner_id/, fn ->
      Connections.user_connection(%{}, tenant_id: "tenant_1")
    end

    assert_raise ArgumentError, ~r/Google connection requires :subject/, fn ->
      Connections.domain_delegated_service_account_connection(%{}, tenant_id: "tenant_1")
    end
  end
end
