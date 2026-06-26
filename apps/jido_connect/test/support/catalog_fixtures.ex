defmodule Jido.Connect.CatalogFixtures do
  alias Jido.Connect

  defmodule Integration do
    def run(input, _context), do: {:ok, input}
    def poll(_config, _context), do: {:ok, %{signals: [], checkpoint: nil}}

    def integration do
      field = Connect.Field.new!(%{name: :id, type: :string, required?: true})

      auth =
        Connect.AuthProfile.new!(%{
          id: :user,
          kind: :oauth2,
          owner: :app_user,
          subject: :user,
          label: "User OAuth",
          scopes: ["read"],
          default_scopes: ["read"],
          credential_fields: [:access_token],
          lease_fields: [:access_token],
          default?: true
        })

      action =
        Connect.ActionSpec.new!(%{
          id: "catalog.item.get",
          name: :get_item,
          label: "Get item",
          tags: [:inventory, :read_model],
          resource: :item,
          verb: :get,
          data_classification: :workspace_metadata,
          auth_profile: :user,
          policies: [:item_access],
          handler: __MODULE__,
          input: [field],
          output: [field],
          input_schema: Zoi.object(%{id: Zoi.string()}),
          output_schema: Zoi.object(%{id: Zoi.string()}),
          scopes: ["read"]
        })

      trigger =
        Connect.TriggerSpec.new!(%{
          id: "catalog.item.created",
          name: :item_created,
          kind: :poll,
          label: "Item created",
          tags: [:inventory, :events],
          resource: :item,
          verb: :watch,
          data_classification: :workspace_metadata,
          auth_profile: :user,
          policies: [:item_access],
          handler: __MODULE__,
          config: [field],
          signal: [field],
          config_schema: Zoi.object(%{id: Zoi.string()}),
          signal_schema: Zoi.object(%{id: Zoi.string()}),
          scopes: ["read"],
          interval_ms: 1_000,
          checkpoint: :updated_at,
          dedupe: %{field: :id}
        })

      Connect.Spec.new!(%{
        id: :catalog,
        name: "Catalog",
        category: :test,
        package: :jido_connect_catalog,
        tags: [:catalog_test],
        docs: ["https://example.test/docs"],
        metadata: %{package: :jido_connect_catalog, version: "1.2.3"},
        policies: [
          Connect.PolicyRequirement.new!(%{
            id: :item_access,
            label: "Item access",
            decision: :allow_operation
          })
        ],
        auth_profiles: [auth],
        actions: [action],
        triggers: [trigger]
      })
    end
  end

  defmodule OtherIntegration do
    def run(input, _context), do: {:ok, input}

    def integration do
      spec = Integration.integration()

      %{
        spec
        | id: :other_catalog,
          name: "Other Catalog",
          package: :jido_connect_other_catalog,
          metadata: %{package: :jido_connect_other_catalog}
      }
    end
  end

  defmodule RaisingIntegration do
    def integration, do: raise("catalog exploded")
  end

  defmodule InvalidIntegration do
    def integration, do: %{id: :not_a_spec}
  end

  defmodule MissingIntegrationCallback do
  end

  def context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_catalog",
        provider: :catalog,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["read"]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :app_user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_catalog",
        provider: :catalog,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        scopes: ["read"],
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        fields: %{}
      })

    {context, lease}
  end
end
