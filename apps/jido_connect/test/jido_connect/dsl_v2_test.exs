defmodule Jido.Connect.DslV2Test do
  use ExUnit.Case, async: true

  alias Jido.Connect

  defmodule Handler do
    def run(_params, _context), do: {:ok, %{}}
  end

  defmodule Integration do
    use Jido.Connect

    integration do
      id :v2_demo
      name "V2 Demo"
      description "Demo connector for V2 DSL coverage."
      category :productivity
      docs ["https://example.test/docs"]
    end

    catalog do
      package :jido_connect_v2_demo
      status :experimental
      tags [:demo, :catalog]
      visibility :public

      capability :signed_webhooks do
        kind :webhook
        feature :signed_request_verification
        label "Signed webhooks"
      end
    end

    schemas do
      schema :item do
        label "Item"
        field :id, :string, required?: true
        field :name, :string
      end
    end

    auth do
      api_key :tenant do
        default? true
        owner :tenant
        subject :account
        label "Tenant API key"
        setup :api_key
        credential_fields [:api_key]
        lease_fields [:api_key]
        scopes ["items:read", "items:write"]
        default_scopes ["items:read"]
      end
    end

    policies do
      policy :tenant_access do
        label "Tenant access"
        subject {:connection, :owner}
        owner {:connection, :owner}
        decision :allow_operation
      end
    end

    actions do
      action :list_items do
        id "v2.item.list"
        resource :item
        verb :list
        data_classification :workspace_content
        label "List items"
        handler Handler
        effect :read
        input_schema :item
        output_schema :item

        access do
          auth :tenant
          policies [:tenant_access]
          scopes ["items:read"]
        end
      end
    end

    triggers do
      webhook :item_created do
        id "v2.item.created"
        resource :item
        verb :watch
        data_classification :workspace_content
        label "Item created"
        verification %{kind: :hmac_sha256, header: "x-demo-signature"}
        handler Handler
        signal_schema :item

        access do
          auth :tenant
          policies [:tenant_access]
          scopes ["items:read"]
        end

        config do
          field :secret_ref, :string, required?: true
        end
      end
    end
  end

  defmodule ActionFragment do
    use Spark.Dsl.Fragment, of: Jido.Connect

    actions do
      action :fragment_list do
        id "fragment.item.list"
        resource :item
        verb :list
        data_classification :workspace_content
        label "Fragment list"
        handler Jido.Connect.DslV2Test.Handler
        effect :read

        access do
          policies [:tenant_access]
          scopes ["items:read"]
        end

        input do
          field :id, :string
        end
      end
    end
  end

  defmodule FragmentedIntegration do
    use Jido.Connect, fragments: [ActionFragment]

    integration do
      id :fragmented_demo
      name "Fragmented Demo"
    end

    auth do
      api_key :tenant do
        default? true
        owner :tenant
        subject :account
        credential_fields [:api_key]
        lease_fields [:api_key]
        scopes ["items:read"]
      end
    end

    policies do
      policy :tenant_access do
        decision :allow_operation
      end
    end
  end

  defmodule ServiceAccountIntegration do
    use Jido.Connect

    integration do
      id :service_account_demo
      name "Service Account Demo"
      description "Demo connector for service-account auth coverage."
      category :productivity
      docs ["https://example.test/docs"]
    end

    auth do
      service_account :service_account do
        owner :system
        subject :service_account
        label "Service account"
        credential_fields [:client_email, :private_key]
        lease_fields [:access_token]
      end

      domain_delegated_service_account :domain_delegated_service_account do
        owner :tenant
        subject :workspace_user
        label "Domain delegated service account"
        setup :google_domain_wide_delegation
        credential_fields [:client_email, :private_key, :subject]
        lease_fields [:access_token]
      end
    end

    actions do
      action :list_items do
        id "service.item.list"
        resource :item
        verb :list
        data_classification :workspace_metadata
        handler Handler
        effect :read

        access do
          auth [:service_account, :domain_delegated_service_account], default: :service_account
        end
      end
    end
  end

  test "V2 DSL compiles catalog, schemas, policy, requirements, and webhook metadata" do
    spec = Integration.integration()

    assert spec.package == :jido_connect_v2_demo
    assert spec.status == :experimental
    assert spec.tags == [:demo, :catalog]
    assert [%{feature: :signed_request_verification}] = spec.capabilities
    assert [%{id: :item, label: "Item"}] = spec.schemas
    assert [%{id: :tenant_access, decision: :allow_operation}] = spec.policies

    assert [%{id: :tenant, credential_fields: [:api_key], setup: :api_key}] =
             spec.auth_profiles

    assert {:ok,
            %{
              id: "v2.item.list",
              auth_profile: :tenant,
              auth_profiles: [:tenant],
              policies: [:tenant_access],
              resource: :item,
              verb: :list,
              scopes: ["items:read"]
            } = action} = Connect.action(spec, "v2.item.list")

    assert Enum.map(action.input, & &1.name) == [:id, :name]
    assert Enum.map(action.output, & &1.name) == [:id, :name]

    assert {:ok,
            %{
              id: "v2.item.created",
              kind: :webhook,
              verification: %{kind: :hmac_sha256},
              policies: [:tenant_access]
            } = trigger} = Connect.trigger(spec, "v2.item.created")

    assert Enum.map(trigger.signal, & &1.name) == [:id, :name]
  end

  test "V2 DSL generates provider manifest and module introspection" do
    assert %Connect.Catalog.Manifest{
             id: :v2_demo,
             package: :jido_connect_v2_demo,
             status: :experimental,
             generated_modules: %{
               actions: [Jido.Connect.DslV2Test.Integration.Actions.ListItems],
               sensors: [Jido.Connect.DslV2Test.Integration.Sensors.ItemCreated],
               plugin: Jido.Connect.DslV2Test.Integration.Plugin
             }
           } = Integration.jido_connect_manifest()

    assert Integration.jido_connect_modules() == %{
             actions: [Jido.Connect.DslV2Test.Integration.Actions.ListItems],
             sensors: [Jido.Connect.DslV2Test.Integration.Sensors.ItemCreated],
             plugin: Jido.Connect.DslV2Test.Integration.Plugin
           }
  end

  test "V2 DSL compiles service-account auth profiles" do
    spec = ServiceAccountIntegration.integration()

    assert [
             %{id: :service_account, kind: :service_account, setup: :service_account},
             %{
               id: :domain_delegated_service_account,
               kind: :domain_delegated_service_account,
               setup: :google_domain_wide_delegation
             }
           ] = spec.auth_profiles

    assert {:ok,
            %{
              auth_profile: :service_account,
              auth_profiles: [:service_account, :domain_delegated_service_account]
            }} = Connect.action(spec, "service.item.list")
  end

  test "V2 projections expose policy and resource metadata" do
    action_projection = Integration.Actions.ListItems.jido_connect_projection()
    sensor_projection = Integration.Sensors.ItemCreated.jido_connect_projection()

    assert action_projection.resource == :item
    assert action_projection.verb == :list
    assert action_projection.policies == [:tenant_access]
    assert sensor_projection.kind == :webhook
    assert sensor_projection.policies == [:tenant_access]
  end

  test "DSL fragments can split large provider declarations across modules" do
    assert {:ok,
            %{
              id: "fragment.item.list",
              auth_profile: :tenant,
              policies: [:tenant_access],
              scopes: ["items:read"]
            }} = Connect.action(FragmentedIntegration, "fragment.item.list")

    assert FragmentedIntegration.jido_action_modules() == [
             Jido.Connect.DslV2Test.FragmentedIntegration.Actions.FragmentList
           ]
  end

  test "DSL verifier requires canonical operation metadata" do
    error =
      assert_raise Spark.Error.DslError, ~r/Operation must declare data_classification/, fn ->
        compile_bad!(
          quote do
            actions do
              action :missing_classification do
                id "bad.item.list"
                resource :item
                verb :list
                label "Missing classification"
                handler Jido.Connect.DslV2Test.Handler
                effect :read

                access do
                  auth :tenant
                  policies [:tenant_access]
                  scopes ["items:read"]
                end
              end
            end
          end
        )
      end

    assert error.path == [:actions, :missing_classification]
  end

  test "DSL verifier rejects mixed canonical and legacy access" do
    error =
      assert_raise Spark.Error.DslError, ~r/Do not mix access with legacy requirements/, fn ->
        compile_bad!(
          quote do
            actions do
              action :mixed_access do
                id "bad.item.mixed"
                resource :item
                verb :list
                data_classification :workspace_metadata
                label "Mixed access"
                handler Jido.Connect.DslV2Test.Handler
                effect :read

                access do
                  auth :tenant
                  policies [:tenant_access]
                  scopes ["items:read"]
                end

                requirements do
                  scopes ["items:read"]
                end
              end
            end
          end
        )
      end

    assert error.path == [:actions, :mixed_access]
  end

  test "DSL verifier requires confirmation for mutating effects" do
    error =
      assert_raise Spark.Error.DslError, ~r/Mutating effect must declare confirmation/, fn ->
        compile_bad!(
          quote do
            actions do
              action :unconfirmed_write do
                id "bad.item.create"
                resource :item
                verb :create
                data_classification :workspace_content
                label "Unconfirmed write"
                handler Jido.Connect.DslV2Test.Handler
                effect :write

                access do
                  auth :tenant
                  policies [:tenant_access]
                  scopes ["items:write"]
                end
              end
            end
          end
        )
      end

    assert error.path == [:actions, :unconfirmed_write]
  end

  test "DSL spec builder preserves structured build errors" do
    error =
      assert_raise Spark.Error.DslError,
                   ~r/ArgumentError.*cannot declare both inline fields/s,
                   fn ->
                     compile_bad!(
                       quote do
                         schemas do
                           schema :item do
                             field :id, :string
                           end
                         end

                         actions do
                           action :bad_schema_reference do
                             id "bad.schema"
                             resource :item
                             verb :list
                             data_classification :workspace_content
                             label "Bad schema"
                             handler Jido.Connect.DslV2Test.Handler
                             effect :read
                             input_schema :item

                             input do
                               field :id, :string
                             end

                             access do
                               auth :tenant
                               policies [:tenant_access]
                               scopes ["items:read"]
                             end
                           end
                         end
                       end
                     )
                   end

    assert error.path == [:actions, :bad_schema_reference]
  end

  defp compile_bad!(body) do
    module = Module.concat(__MODULE__, "BadDsl#{System.unique_integer([:positive])}")

    Code.compile_quoted(
      quote do
        defmodule unquote(module) do
          use Jido.Connect

          integration do
            id :bad_dsl
            name "Bad DSL"
          end

          auth do
            api_key :tenant do
              default? true
              owner :tenant
              subject :account
              credential_fields [:api_key]
              lease_fields [:api_key]
              scopes ["items:read", "items:write"]
            end
          end

          policies do
            policy :tenant_access do
              decision :allow_operation
            end
          end

          unquote(body)
        end
      end
    )
  end
end
