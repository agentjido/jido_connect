defmodule Jido.Connect.Microsoft.AccountTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.Account

  test "normalizes Microsoft Graph user payloads" do
    assert {:ok, account} =
             Account.from_graph_user(%{
               "id" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
               "mail" => "user@example.com",
               "displayName" => "User Name",
               "preferredLanguage" => "en-US",
               "tenantId" => "tenant-guid"
             })

    assert account.id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    assert account.email == "user@example.com"
    assert account.display_name == "User Name"
    assert account.tenant_id == "tenant-guid"
    assert account.locale == "en-US"

    assert Account.to_subject(account) == %{
             microsoft_account_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
             email: "user@example.com",
             display_name: "User Name",
             tenant_id: "tenant-guid"
           }
  end

  test "falls back to userPrincipalName when mail is absent" do
    assert {:ok, account} =
             Account.from_graph_user(%{
               "id" => "aaa",
               "userPrincipalName" => "upn@example.com",
               "displayName" => "UPN User"
             })

    assert account.email == "upn@example.com"
  end

  test "supports metadata and direct constructors" do
    assert %Account{email: "direct@example.com", metadata: %{source: :direct}} =
             Account.new!(%{email: "direct@example.com", metadata: %{source: :direct}})

    assert {:ok, account} =
             Account.from_graph_user(
               %{"id" => "123", "mail" => "meta@example.com"},
               %{source: :graph_user}
             )

    assert account.id == "123"
    assert account.email == "meta@example.com"
    assert account.metadata == %{source: :graph_user}
    assert Account.schema()
  end
end
