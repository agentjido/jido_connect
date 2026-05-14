defmodule Jido.Connect.Dsl.Entities.Auth do
  @moduledoc false

  alias Jido.Connect.Dsl

  def auth_profiles do
    %Spark.Dsl.Entity{
      name: :auth_profiles,
      target: Dsl.AuthProfiles,
      args: [:profiles],
      schema: [
        profiles: [type: {:list, :atom}, required: true],
        default: [type: :atom]
      ]
    }
  end

  def access do
    %Spark.Dsl.Entity{
      name: :access,
      target: Dsl.Access,
      entities: [
        auth: [access_auth()],
        scopes: [access_scopes()]
      ],
      schema: [
        policies: [type: {:list, :atom}, default: []]
      ],
      singleton_entity_keys: [:auth, :scopes]
    }
  end

  def requirements do
    %Spark.Dsl.Entity{
      name: :requirements,
      target: Dsl.Requirements,
      schema: [
        scopes: [type: {:list, :string}, default: []],
        dynamic_scopes: [type: :module]
      ]
    }
  end

  def oauth2 do
    %Spark.Dsl.Entity{
      name: :oauth2,
      target: Dsl.AuthProfile,
      args: [:id],
      identifier: :id,
      auto_set_fields: [kind: :oauth2],
      schema: oauth2_schema()
    }
  end

  def api_key do
    %Spark.Dsl.Entity{
      name: :api_key,
      target: Dsl.AuthProfile,
      args: [:id],
      identifier: :id,
      auto_set_fields: [kind: :api_key],
      schema: credential_auth_schema()
    }
  end

  def app_installation do
    %Spark.Dsl.Entity{
      name: :app_installation,
      target: Dsl.AuthProfile,
      args: [:id],
      identifier: :id,
      auto_set_fields: [kind: :app_installation],
      schema: credential_auth_schema()
    }
  end

  def service_account do
    %Spark.Dsl.Entity{
      name: :service_account,
      target: Dsl.AuthProfile,
      args: [:id],
      identifier: :id,
      auto_set_fields: [kind: :service_account],
      schema: credential_auth_schema()
    }
  end

  def domain_delegated_service_account do
    %Spark.Dsl.Entity{
      name: :domain_delegated_service_account,
      target: Dsl.AuthProfile,
      args: [:id],
      identifier: :id,
      auto_set_fields: [kind: :domain_delegated_service_account],
      schema: credential_auth_schema()
    }
  end

  defp access_auth do
    %Spark.Dsl.Entity{
      name: :auth,
      target: Dsl.AuthProfiles,
      args: [:profiles],
      schema: [
        profiles: [type: :any, required: true],
        default: [type: :atom]
      ]
    }
  end

  defp access_scopes do
    %Spark.Dsl.Entity{
      name: :scopes,
      target: Dsl.ScopeRequirements,
      args: [:scopes],
      schema: [
        scopes: [type: {:list, :string}, required: true],
        resolver: [type: :module]
      ]
    }
  end

  defp oauth2_schema do
    credential_auth_schema() ++
      [
        authorize_url: [type: :string, required: true],
        token_url: [type: :string, required: true],
        callback_path: [type: :string],
        token_field: [type: :atom],
        refresh_token_field: [type: :atom],
        pkce?: [type: :boolean, default: false],
        refresh?: [type: :boolean, default: false],
        revoke?: [type: :boolean, default: false]
      ]
  end

  defp credential_auth_schema do
    [
      id: [type: :atom, required: true],
      default?: [type: :boolean, default: false],
      owner: [type: :atom, required: true],
      subject: [type: :atom, required: true],
      label: [type: :string],
      credential_fields: [type: {:list, :atom}, default: []],
      lease_fields: [type: {:list, :atom}, default: []],
      setup: [type: :atom],
      scopes: [type: {:list, :string}, default: []],
      default_scopes: [type: {:list, :string}, default: []],
      optional_scopes: [type: {:list, :string}, default: []],
      metadata: [type: :map, default: %{}]
    ]
  end
end
