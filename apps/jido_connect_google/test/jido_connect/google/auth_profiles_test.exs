defmodule Jido.Connect.Google.AuthProfilesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.{AuthProfile, AuthProfiles}

  test "models user and service account auth profiles" do
    assert AuthProfiles.ids() == [:user, :service_account, :domain_delegated_service_account]
    assert Enum.map(AuthProfiles.all(), & &1.id) == AuthProfiles.ids()

    assert %AuthProfile{
             id: :user,
             kind: :oauth2,
             owner: :app_user,
             subject: :user,
             default?: true,
             implemented?: true
           } = AuthProfiles.fetch!(:user)

    assert %AuthProfile{
             id: :service_account,
             kind: :service_account,
             implemented?: true
           } = AuthProfiles.fetch!(:service_account)

    assert %AuthProfile{
             id: :domain_delegated_service_account,
             kind: :domain_delegated_service_account,
             owner: :tenant,
             implemented?: true
           } = AuthProfiles.fetch!(:domain_delegated_service_account)
  end

  test "fetches profiles safely and rejects unknown profile ids" do
    assert {:ok, %AuthProfile{id: :user}} = AuthProfiles.fetch(:user)
    assert :error = AuthProfiles.fetch(:missing)

    assert_raise ArgumentError, ~r/unknown Google auth profile :missing/, fn ->
      AuthProfiles.fetch!(:missing)
    end
  end

  test "auth profile schema applies connector defaults" do
    assert %AuthProfile{
             token_field: :access_token,
             credential_fields: [],
             lease_fields: [:access_token],
             scopes: [],
             default_scopes: [],
             optional_scopes: [],
             default?: false,
             implemented?: true,
             metadata: %{}
           } =
             AuthProfile.new!(%{
               id: :custom,
               kind: :oauth2,
               owner: :app_user,
               subject: :user,
               label: "Custom Google OAuth",
               setup: :oauth2_authorization_code
             })

    assert {:error, _error} = AuthProfile.new(%{id: :incomplete})
    assert AuthProfile.schema()
  end
end
