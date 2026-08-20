defmodule Jido.Connect.BitbucketTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Bitbucket
  alias Jido.Connect.Error

  defmodule NoCallClient do
    def list_pull_requests(_workspace, _repository, _request, _opts) do
      send(self(), :unexpected_bitbucket_call)
      {:error, :unexpected_call}
    end
  end

  test "declares one reviewed Bitbucket reader action" do
    spec = Bitbucket.integration()

    assert spec.id == :bitbucket
    assert spec.package == :jido_connect_bitbucket
    assert spec.name == "Bitbucket"
    assert spec.category == :developer_tools
    assert spec.status == :experimental
    assert spec.tags == [:source_control, :code_review, :developer_tools]
    assert spec.triggers == []

    assert [action] = spec.actions
    assert action.id == "bitbucket.pull_request.list"
    assert action.resource == :pull_request
    assert action.verb == :list
    assert action.risk == :read
    assert action.confirmation == :none
    assert action.handler == Jido.Connect.Bitbucket.Handlers.Actions.ListPullRequests

    assert [%{id: :api_token, kind: :api_key} = profile] = spec.auth_profiles
    assert profile.default?
    assert profile.credential_fields == [:email, :api_token]
    assert profile.lease_fields == [:email, :api_token]
    assert profile.default_scopes == ["read:pullrequest:bitbucket"]
  end

  test "publishes strict slug, state, and paging bounds" do
    [action] = Bitbucket.integration().actions
    fields = Map.new(action.input, &{&1.name, &1})

    for slug <- [:workspace, :repository] do
      assert fields[slug].required?
      assert fields[slug].min_length == 1
      assert fields[slug].max_length == 255
      assert fields[slug].metadata.pattern == "^[A-Za-z0-9._-]+$"
    end

    assert fields.state.enum == ["open", "merged", "declined", "superseded"]
    assert fields.state.default == "open"
    assert fields.limit.minimum == 1
    assert fields.limit.maximum == 50
    assert fields.limit.default == 20
    assert fields.page.minimum == 1
    assert fields.page.maximum == 10_000
    assert fields.page.default == 1

    assert Enum.map(action.output, & &1.name) == [
             :kind,
             :account,
             :workspace,
             :repository,
             :state,
             :count,
             :page,
             :page_length,
             :total,
             :next_page,
             :items
           ]
  end

  test "registers generated modules and package discovery" do
    assert Application.get_env(:jido_connect_bitbucket, :jido_connect_providers) == [Bitbucket]
    assert Bitbucket.jido_action_modules() == [Jido.Connect.Bitbucket.Actions.ListPullRequests]
    assert Bitbucket.jido_sensor_modules() == []
    assert Bitbucket.jido_plugin_module() == Jido.Connect.Bitbucket.Plugin

    assert %Connect.Catalog.Manifest{
             id: :bitbucket,
             package: :jido_connect_bitbucket,
             generated_modules: %{
               actions: [Jido.Connect.Bitbucket.Actions.ListPullRequests],
               sensors: [],
               plugin: Jido.Connect.Bitbucket.Plugin
             }
           } = Bitbucket.jido_connect_manifest()

    assert {:module, Jido.Connect.Bitbucket.Actions.ListPullRequests} =
             Code.ensure_loaded(Jido.Connect.Bitbucket.Actions.ListPullRequests)

    assert function_exported?(Jido.Connect.Bitbucket.Actions.ListPullRequests, :run, 2)
  end

  test "reader catalog pack exposes only the reviewed action" do
    assert [pack] = Bitbucket.catalog_packs()
    assert pack.id == :bitbucket_reader
    assert pack.filters == %{provider: :bitbucket}
    assert pack.allowed_tools == ["bitbucket.pull_request.list"]
    assert pack.metadata == %{package: :jido_connect_bitbucket, risk: :read}

    assert [%{tool: %{id: "bitbucket.pull_request.list", risk: :read}}] =
             Connect.Catalog.search_tools("bitbucket",
               modules: [Bitbucket],
               packs: Bitbucket.catalog_packs(),
               pack: :bitbucket_reader
             )
  end

  test "generated action executes through the injected client" do
    runtime = Jido.Connect.Bitbucket.TestRuntime.build()

    assert {:ok, result} =
             Connect.invoke(
               Bitbucket,
               "bitbucket.pull_request.list",
               %{workspace: "acme", repository: "widgets"},
               runtime_opts(runtime)
             )

    assert result.kind == "pull_requests"
    assert result.account == "bitbucket-account-1"
    assert result.state == "open"
    assert result.count == 1
    assert [%{id: 42, author: %{display_name: "Ada Lovelace"}}] = result.items
    assert_received {:bitbucket_list_pull_requests, [state: "open", limit: 20, page: 1]}
  end

  test "runtime rejects invalid bounds and unsafe slugs before the client runs" do
    runtime = Jido.Connect.Bitbucket.TestRuntime.build(provider_client: NoCallClient)

    for input <- [
          %{workspace: "acme", repository: "widgets", limit: 0},
          %{workspace: "acme", repository: "widgets", limit: 51},
          %{workspace: "acme", repository: "widgets", page: 0},
          %{workspace: "acme", repository: "widgets", page: 10_001}
        ] do
      assert {:error, %Error.ValidationError{}} =
               Connect.invoke(
                 Bitbucket,
                 "bitbucket.pull_request.list",
                 input,
                 runtime_opts(runtime)
               )
    end

    for input <- [
          %{workspace: "../acme", repository: "widgets"},
          %{workspace: "acme", repository: "widgets/other"},
          %{workspace: "acme?admin=true", repository: "widgets"}
        ] do
      assert {:error, %Error.ValidationError{reason: :invalid_bitbucket_slug}} =
               Connect.invoke(
                 Bitbucket,
                 "bitbucket.pull_request.list",
                 input,
                 runtime_opts(runtime)
               )
    end

    refute_received :unexpected_bitbucket_call
  end

  defp runtime_opts(runtime) do
    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    [
      context: runtime.context,
      credential_lease: lease,
      provider_client: runtime.provider_client
    ]
  end
end
