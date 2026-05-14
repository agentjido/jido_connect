defmodule Jido.Connect.Gmail.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Gmail.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"
  @send_scope "https://www.googleapis.com/auth/gmail.send"
  @compose_scope "https://www.googleapis.com/auth/gmail.compose"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"

  test "declares Gmail read, broad, mutation, and legacy-compatible scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "missing product grant falls back to narrow metadata read",
        operation: "google.gmail.message.get",
        granted: [],
        expected: @metadata_scope
      },
      %{
        label: "narrow metadata read remains least-privilege",
        operation: "google.gmail.thread.get",
        granted: [@metadata_scope],
        expected: @metadata_scope
      },
      %{
        label: "broad readonly grant can satisfy metadata reads",
        operation: "google.gmail.messages.list",
        granted: [@readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "modify grant can satisfy metadata reads",
        operation: "google.gmail.labels.list",
        granted: [@modify_scope],
        expected: @modify_scope
      },
      %{
        label: "send action prefers explicit send scope",
        operation: "google.gmail.message.send",
        granted: [@send_scope],
        expected: @send_scope
      },
      %{
        label: "compose grant remains accepted for send-compatible workflows",
        operation: "google.gmail.message.send",
        granted: [@compose_scope],
        expected: @compose_scope
      },
      %{
        label: "draft mutation uses compose scope",
        operation: "google.gmail.draft.create",
        granted: [],
        expected: @compose_scope
      },
      %{
        label: "label mutation requires modify scope",
        operation: "google.gmail.message.labels.apply",
        granted: [@readonly_scope],
        expected: @modify_scope
      },
      %{
        label: "attachment read requires readonly when only metadata is granted",
        operation: "google.gmail.message.attachment.get",
        granted: [@metadata_scope],
        expected: @readonly_scope
      },
      %{
        label: "attachment read accepts modify as a broader content grant",
        operation: "google.gmail.message.attachment.get",
        granted: [@modify_scope],
        expected: @modify_scope
      },
      %{
        label: "watch lifecycle stays in Gmail metadata scope",
        operation: "google.gmail.watch.start",
        granted: [@metadata_scope],
        expected: @metadata_scope
      }
    ])
  end
end
