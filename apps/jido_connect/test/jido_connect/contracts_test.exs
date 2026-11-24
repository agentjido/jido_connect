defmodule Jido.Connect.ContractsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect

  test "context validates host callback references" do
    attrs = %{
      tenant_id: "tenant_1",
      actor: %{id: "actor_1"},
      policy: __MODULE__,
      credential_resolver: __MODULE__,
      connection_resolver: {__MODULE__, :resolve}
    }

    assert {:ok,
            %Connect.Context{
              policy: __MODULE__,
              credential_resolver: __MODULE__,
              connection_resolver: {__MODULE__, :resolve}
            }} = Connect.Context.new(attrs)

    for {field, value} <- [
          policy: fn _op, _input, _context, _connection -> :ok end,
          credential_resolver: "Resolver",
          connection_resolver: {__MODULE__, :resolve, []}
        ] do
      assert {:error, _reason} = Connect.Context.new(Map.put(attrs, field, value))
    end
  end

  test "all public contract structs expose Zoi schemas and constructors" do
    field =
      Connect.Field.new!(%{
        name: :repo,
        type: :string,
        required?: true,
        description: "Repository"
      })

    assert {:ok, %Connect.Field{name: :repo}} = Connect.Field.new(Map.from_struct(field))
    assert Connect.Field.schema()

    auth_profile =
      Connect.AuthProfile.new!(%{
        id: :user,
        kind: :oauth2,
        owner: :user,
        subject: :user,
        label: "User",
        authorize_url: "https://example.test/authorize",
        token_url: "https://example.test/token",
        scopes: ["repo"],
        default?: true
      })

    action =
      Connect.ActionSpec.new!(%{
        id: "demo.repo.show",
        name: :show_repo,
        label: "Show repo",
        description: "Show a repository",
        resource: :repo,
        verb: :get,
        data_classification: :workspace_metadata,
        auth_profile: :user,
        handler: __MODULE__,
        input: [field],
        output: [field],
        input_schema: Zoi.object(%{repo: Zoi.string()}),
        output_schema: Zoi.object(%{repo: Zoi.string()}),
        scopes: ["repo"]
      })

    trigger =
      Connect.TriggerSpec.new!(%{
        id: "demo.repo.changed",
        name: :repo_changed,
        kind: :poll,
        label: "Repo changed",
        description: "Repository changed",
        resource: :repo,
        verb: :watch,
        data_classification: :workspace_metadata,
        auth_profile: :user,
        handler: __MODULE__,
        config: [field],
        signal: [field],
        config_schema: Zoi.object(%{repo: Zoi.string()}),
        signal_schema: Zoi.object(%{repo: Zoi.string()}),
        scopes: ["repo"],
        checkpoint: :updated_at,
        dedupe: %{field: :repo}
      })

    spec =
      Connect.Spec.new!(%{
        id: :demo,
        name: "Demo",
        category: :test,
        auth_profiles: [auth_profile],
        actions: [action],
        triggers: [trigger]
      })

    assert {:ok, %Connect.Spec{id: :demo}} = Connect.Spec.new(Map.from_struct(spec))
    assert Connect.AuthProfile.schema()
    assert Connect.ActionSpec.schema()
    assert Connect.TriggerSpec.schema()
    assert Connect.Spec.schema()

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :demo,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["repo"]
      })

    selector =
      Connect.ConnectionSelector.new!(%{
        provider: :demo,
        profile: :user,
        strategy: :tenant_default,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        required_scopes: ["repo"]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection,
        connection_selector: selector
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        fields: %{access_token: "token"}
      })

    run =
      Connect.Run.new!(%{
        id: "run_1",
        integration_id: :demo,
        operation_id: "demo.repo.show",
        tenant_id: "tenant_1",
        status: :ok,
        inserted_at: DateTime.utc_now()
      })

    event =
      Connect.Event.new!(%{
        id: "event_1",
        run_id: run.id,
        type: :action_completed,
        timestamp: DateTime.utc_now(),
        payload: %{ok: true}
      })

    provider_response =
      Connect.ProviderResponse.new!(%{
        provider: :demo,
        status: 200,
        body: %{"ok" => true}
      })

    webhook_delivery =
      Connect.WebhookDelivery.verified!(:demo,
        delivery_id: "delivery_1",
        event: "demo.created",
        payload: %{"ok" => true}
      )

    capability =
      Connect.ConnectorCapability.new!(%{
        id: "demo.actions",
        provider: :demo,
        kind: :actions,
        feature: :generated_jido_actions,
        label: "Generated Jido actions"
      })

    assert {:ok, %Connect.Connection{id: "conn_1"}} =
             Connect.Connection.new(Map.from_struct(connection))

    assert {:ok, %Connect.Context{tenant_id: "tenant_1"}} =
             Connect.Context.new(Map.from_struct(context))

    assert {:ok, %Connect.ConnectionSelector{strategy: :tenant_default}} =
             Connect.ConnectionSelector.new(Map.from_struct(selector))

    assert {:ok, %Connect.CredentialLease{connection_id: "conn_1"}} =
             Connect.CredentialLease.new(Map.from_struct(lease))

    assert {:ok, %Connect.Run{id: "run_1"}} = Connect.Run.new(Map.from_struct(run))
    assert {:ok, %Connect.Event{id: "event_1"}} = Connect.Event.new(Map.from_struct(event))

    assert {:ok, %Connect.ProviderResponse{provider: :demo}} =
             Connect.ProviderResponse.new(Map.from_struct(provider_response))

    assert {:ok, %Connect.WebhookDelivery{delivery_id: "delivery_1"}} =
             Connect.WebhookDelivery.new(Map.from_struct(webhook_delivery))

    assert {:ok, %Connect.ConnectorCapability{id: "demo.actions"}} =
             Connect.ConnectorCapability.new(Map.from_struct(capability))

    assert Connect.Connection.schema()
    assert Connect.ConnectionSelector.schema()
    assert Connect.Context.schema()
    assert Connect.CredentialLease.schema()
    assert Connect.Run.schema()
    assert Connect.Event.schema()
    assert Connect.ProviderResponse.schema()
    assert Connect.WebhookDelivery.schema()
    assert Connect.ConnectorCapability.schema()
  end
end
