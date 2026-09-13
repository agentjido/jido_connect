defmodule Jido.Connect.Microsoft.AuthProfilesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.{AuthProfile, AuthProfiles}

  test "models user auth profile" do
    assert AuthProfiles.ids() == [:user, :application]
    assert Enum.map(AuthProfiles.all(), & &1.id) == AuthProfiles.ids()

    assert %AuthProfile{
             id: :user,
             kind: :oauth2,
             owner: :app_user,
             subject: :user,
             default?: true,
             implemented?: true
           } = AuthProfiles.fetch!(:user)
  end

  test "models application auth profile" do
    assert %AuthProfile{
             id: :application,
             kind: :oauth2,
             owner: :tenant,
             subject: :service_principal,
             setup: :oauth2_client_credentials,
             credential_fields: [:client_id, :client_secret, :tenant_id],
             lease_fields: [:access_token],
             default?: false
           } = AuthProfiles.fetch!(:application)
  end

  test "fetches profiles safely and rejects unknown profile ids" do
    assert {:ok, %AuthProfile{id: :user}} = AuthProfiles.fetch(:user)
    assert {:ok, %AuthProfile{id: :application}} = AuthProfiles.fetch(:application)
    assert :error = AuthProfiles.fetch(:missing)

    assert_raise ArgumentError, ~r/unknown Microsoft auth profile :missing/, fn ->
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
               label: "Custom Microsoft OAuth",
               setup: :oauth2_authorization_code
             })

    assert {:error, _error} = AuthProfile.new(%{id: :incomplete})
    assert AuthProfile.schema()
  end
end
