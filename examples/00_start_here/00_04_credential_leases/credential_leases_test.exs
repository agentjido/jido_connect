Code.require_file("lease_host.ex", __DIR__)
Code.require_file("credential_leases.ex", __DIR__)
Code.require_file("support/github.ex", __DIR__)

defmodule Jido.Connect.Examples.StartHere.CredentialLeasesTest do
  use ExUnit.Case
  @moduletag :integration

  alias Jido.Connect.{Connection, CredentialLease, Error}
  alias Jido.Connect.Examples.StartHere.{CredentialLeases, Host, LeaseHost}
  alias Jido.Connect.Examples.StartHere.CredentialLeases.Fixture
  alias LeaseHost.Credential

  @credential_id "github-reader"
  @credential_key {"example", :github, @credential_id}
  @actor %{id: "review-agent", type: :agent}

  test "a fresh lease uses the current credential while each connection keeps its own grant" do
    widgets = connection("widgets")
    gadgets = connection("gadgets")
    credentials = %{@credential_key => %Credential{access_token: "fixture-v1", scopes: ["repo"]}}

    grants = [
      %{connection: widgets, actor_id: @actor.id, repo: "example/widgets"},
      %{connection: gadgets, actor_id: @actor.id, repo: "example/gadgets"}
    ]

    store =
      start_supervised!(%{
        id: LeaseHost,
        start: {LeaseHost, :start_link, [credentials, grants, Fixture]}
      })

    bindings = %{
      widgets: LeaseHost.binding(store, widgets, @actor),
      gadgets: LeaseHost.binding(store, gadgets, @actor)
    }

    context = %{connect: bindings}

    server =
      Host.with_agent(CredentialLeases, fn server ->
        assert {:ok, %{pull_request: %{title: "Before rotation"}}} =
                 read(server, context, :widgets)

        assert {:ok, %{pull_request: %{title: "Before rotation"}}} =
                 read(server, context, :gadgets)

        # This route has permission for widgets only.
        assert {:error, _reason} = read(server, context, :widgets, "example/gadgets")

        :ok = LeaseHost.rotate_credential(store, @credential_key, "fixture-v2")

        assert {:ok, %{pull_request: %{title: "After rotation"}}} =
                 read(server, context, :widgets)

        assert {:ok, %{pull_request: %{title: "After rotation"}}} =
                 read(server, context, :gadgets)

        :ok = LeaseHost.revoke_grant(store, widgets)
        assert {:error, _reason} = read(server, context, :widgets)
        assert {:ok, committed} = read(server, context, :gadgets)

        :ok = LeaseHost.revoke_credential(store, @credential_key)
        assert {:error, _reason} = read(server, context, :gadgets)
        assert Jido.AgentServer.snapshot(server).agent.state == committed
        server
      end)

    refute Process.alive?(server)
  end

  test "lease scope and version come from the credential while the lease is bound to one connection" do
    widgets = connection("widgets")
    gadgets = connection("gadgets")

    credentials = %{
      @credential_key => %Credential{access_token: "fixture-v2", scopes: [], version: 2}
    }

    grants = [%{connection: widgets, actor_id: @actor.id, repo: "example/widgets"}]

    store =
      start_supervised!(%{
        id: LeaseHost,
        start: {LeaseHost, :start_link, [credentials, grants, Fixture]}
      })

    context = LeaseHost.binding(store, widgets, @actor)
    input = %{repo: "example/widgets", pull_number: 42}

    assert {:ok, lease} =
             LeaseHost.resolve_lease(context, "github.pull_request.get", input)

    assert %CredentialLease{
             connection_id: "widgets",
             scopes: [],
             metadata: %{credential_version: 2}
           } = lease

    assert CredentialLease.matches_connection?(lease, widgets)
    refute CredentialLease.matches_connection?(lease, gadgets)

    assert {:error, %Error.AuthError{reason: :missing_scopes}} =
             Jido.Connect.invoke(Jido.Connect.GitHub, "github.pull_request.get", input,
               context: context,
               credential_resolver: LeaseHost
             )
  end

  defp connection(id) do
    Connection.new!(%{
      id: id,
      provider: :github,
      profile: :user,
      tenant_id: "example",
      owner_type: :tenant,
      owner_id: "example",
      credential_ref: @credential_id,
      status: :connected,
      scopes: ["repo"]
    })
  end

  defp read(server, context, binding, repo \\ nil) do
    input = %{repo: repo || "example/#{binding}", pull_number: 42}

    signal =
      case binding do
        :widgets -> CredentialLeases.read_widgets_signal!(input)
        :gadgets -> CredentialLeases.read_gadgets_signal!(input)
      end

    Host.call(server, signal, context)
  end
end
