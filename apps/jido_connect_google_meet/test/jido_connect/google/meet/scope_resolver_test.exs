defmodule Jido.Connect.Google.Meet.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @created_scope "https://www.googleapis.com/auth/meetings.space.created"
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @settings_scope "https://www.googleapis.com/auth/meetings.space.settings"

  test "resolves Meet scopes for scaffolded operation shapes" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, @readonly_scope)

    assert ScopeResolver.required_scopes(
             %{id: "google.meet.space.create"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.space.get"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.space.get"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.space.get"},
             %{},
             %{scopes: [@settings_scope]}
           ) == [@settings_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.conference_record.list"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.conference_record.get"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.recording.list"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.transcript.get"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]
  end

  test "resolves Meet artifact read scopes for transcript entries" do
    operation = %{action_id: "google.meet.transcript.entry.list"}

    assert ScopeResolver.required_scopes(operation, %{}, %{scopes: [@readonly_scope]}) ==
             [@readonly_scope]

    assert ScopeResolver.required_scopes(operation, %{}, %{scopes: [@created_scope]}) ==
             [@created_scope]

    assert ScopeResolver.required_scopes(
             operation,
             %{},
             %{scopes: [@readonly_scope, @created_scope]}
           ) == [@created_scope]

    assert ScopeResolver.required_scopes(operation, %{}, %{scopes: []}) == [@readonly_scope]
    assert ScopeResolver.required_scopes(operation, %{}, nil) == [@readonly_scope]
  end

  test "resolves participant reads like the conference record reads" do
    for action_id <- ["google.meet.participant.list", "google.meet.participant.get"] do
      operation = %{action_id: action_id}

      assert ScopeResolver.required_scopes(operation, %{}, %{scopes: [@readonly_scope]}) ==
               [@readonly_scope]

      assert ScopeResolver.required_scopes(operation, %{}, %{scopes: [@created_scope]}) ==
               [@created_scope]

      assert ScopeResolver.required_scopes(
               operation,
               %{},
               %{scopes: [@readonly_scope, @created_scope]}
             ) == [@created_scope]

      assert ScopeResolver.required_scopes(operation, %{}, %{scopes: [@settings_scope]}) ==
               [@readonly_scope]

      assert ScopeResolver.required_scopes(operation, %{}, nil) == [@readonly_scope]
    end
  end

  test "resolves the transcript poll trigger like a conference record and artifact read" do
    trigger = %{id: "google.meet.transcript.available"}

    assert ScopeResolver.required_scopes(trigger, %{}, %{scopes: [@readonly_scope]}) ==
             [@readonly_scope]

    assert ScopeResolver.required_scopes(trigger, %{}, %{scopes: [@created_scope]}) ==
             [@created_scope]

    assert ScopeResolver.required_scopes(trigger, %{}, %{scopes: [@settings_scope]}) ==
             [@readonly_scope]

    for granted <- [[@readonly_scope], [@created_scope], [@settings_scope], []] do
      connection = %{scopes: granted}

      assert ScopeResolver.required_scopes(trigger, %{}, connection) ==
               ScopeResolver.required_scopes(
                 %{action_id: "google.meet.conference_record.list"},
                 %{},
                 connection
               )
    end
  end
end
