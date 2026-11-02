defmodule Jido.Connect.TempoTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Tempo

  @labels [
    "tempo.worklogs.read",
    "tempo.worklogs.write",
    "tempo.accounts.read",
    "tempo.periods.read",
    "tempo.approvals.read"
  ]

  test "registers the :tempo provider" do
    spec = Tempo.integration()

    assert spec.id == :tempo
    assert spec.package == :jido_connect_tempo
    assert spec.status == :experimental

    assert Enum.map(spec.actions, & &1.id) == [
             "tempo.worklogs.list_own",
             "tempo.period.bookability.get"
           ]

    assert spec.triggers == []
    assert Application.get_env(:jido_connect_tempo, :jido_connect_providers) == [Tempo]
  end

  test "declares exactly the API token and OAuth user profiles with the five labels" do
    assert [
             %{id: :api_token, kind: :api_key} = api_token,
             %{id: :oauth2_user, kind: :oauth2} = oauth
           ] = Tempo.integration().auth_profiles

    assert api_token.default? == true
    assert api_token.setup == :api_key_bearer_token
    assert api_token.lease_fields == [:api_token]
    assert api_token.scopes == @labels

    assert oauth.default? == false
    assert oauth.authorize_url == "https://api.tempo.io/oauth/authorize/redirect"
    assert oauth.token_url == "https://api.tempo.io/oauth/token/"
    assert oauth.lease_fields == [:access_token]
    assert oauth.credential_fields == [:access_token, :refresh_token]
    assert oauth.refresh? == true
    assert oauth.revoke? == false
    assert oauth.scopes == @labels
  end

  test "compiles the generated action and plugin surface" do
    actions = [
      Jido.Connect.Tempo.Actions.ListOwnWorklogs,
      Jido.Connect.Tempo.Actions.GetPeriodBookability
    ]

    assert Tempo.jido_action_modules() == actions
    assert Tempo.jido_sensor_modules() == []

    assert %Connect.Catalog.Manifest{
             id: :tempo,
             package: :jido_connect_tempo,
             generated_modules: %{
               actions: ^actions,
               sensors: [],
               plugin: Jido.Connect.Tempo.Plugin
             }
           } = Tempo.jido_connect_manifest()

    for action <- actions do
      assert {:error, %Connect.Error.AuthError{reason: :context_required}} = action.run(%{}, %{})
    end
  end

  test "the generated action carries the DSL metadata of the own worklog read" do
    projection = Jido.Connect.Tempo.Actions.ListOwnWorklogs.jido_connect_projection()

    assert projection.action_id == "tempo.worklogs.list_own"
    assert projection.resource == :worklog
    assert projection.verb == :list
    assert projection.risk == :read
    assert projection.auth_profiles == [:api_token, :oauth2_user]
    assert projection.scope_resolver == Jido.Connect.Tempo.ScopeResolver
    assert projection.policies == []
    assert Enum.map(projection.input, & &1.name) == [:from, :to]

    assert Enum.map(projection.output, & &1.name) == [
             :account_id,
             :from,
             :to,
             :worklogs,
             :complete
           ]

    assert {:ok, %{mutation?: false, data_classification: :personal_data}} =
             Connect.action(Tempo.integration(), "tempo.worklogs.list_own")
  end

  test "the generated action carries the DSL metadata of the period bookability read" do
    projection = Jido.Connect.Tempo.Actions.GetPeriodBookability.jido_connect_projection()

    assert projection.action_id == "tempo.period.bookability.get"
    assert projection.resource == :period
    assert projection.verb == :get
    assert projection.risk == :read
    assert projection.auth_profiles == [:api_token, :oauth2_user]
    assert projection.scope_resolver == Jido.Connect.Tempo.ScopeResolver
    assert projection.policies == []
    assert Enum.map(projection.input, & &1.name) == [:from, :to]

    assert Enum.map(projection.output, & &1.name) == [
             :account_id,
             :from,
             :to,
             :checked_at,
             :complete,
             :state,
             :segments
           ]

    assert {:ok, %{mutation?: false, data_classification: :workspace_metadata} = action} =
             Connect.action(Tempo.integration(), "tempo.period.bookability.get")

    assert action.scopes == ["tempo.periods.read", "tempo.approvals.read"]
  end
end
