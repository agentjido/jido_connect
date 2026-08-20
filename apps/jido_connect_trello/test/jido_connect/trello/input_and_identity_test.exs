defmodule Jido.Connect.Trello.InputAndIdentityTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.Trello.{BoardIdentity, Input}

  @workspace_id "60eeea2273ccd82f506b3977"
  @board_object_id "6a61045166570c8531dc86a7"
  @board_ari "ari:cloud:trello::board/workspace/#{@workspace_id}/#{@board_object_id}"
  @list_ari "ari:cloud:trello::list/workspace/#{@workspace_id}/6a6105e754955319253c46ef"
  @card_ari "ari:cloud:trello::card/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6721"
  @checklist_ari "ari:cloud:trello::checklist/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6723"
  @item_ari "ari:cloud:trello::check-item/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6724"

  test "validates all reviewed input shapes and defaults" do
    cases = [
      {"trello.board.get", %{}, %{}},
      {"trello.list.list", %{}, %{cursor: nil, limit: 25}},
      {"trello.list.get", %{id: @list_ari}, %{id: @list_ari}},
      {"trello.list.create", %{name: "Doing"}, %{name: "Doing", position: nil}},
      {"trello.list.update", %{id: @list_ari, name: "Review"}, %{id: @list_ari, name: "Review"}},
      {"trello.list.move", %{id: @list_ari, position: "top"}, %{id: @list_ari, position: "top"}},
      {"trello.list.archive", %{id: @list_ari}, %{id: @list_ari}},
      {"trello.label.list", %{}, %{cursor: nil, limit: 25}},
      {"trello.card.list", %{}, %{list_id: nil, state: "open", cursor: nil, limit: 25}},
      {"trello.card.get", %{id: "https://trello.com/c/Abc123/card-name"},
       %{id: "https://trello.com/c/Abc123/card-name"}},
      {"trello.card.search", %{query: "blocked"},
       %{query: "blocked", cursor: nil, limit: 10, partial: false}},
      {"trello.card.create", %{list_id: @list_ari, name: "Card"},
       %{list_id: @list_ari, name: "Card", description: nil, due: nil, position: nil}},
      {"trello.card.update", %{card_id: @card_ari, description: ""},
       %{card_id: @card_ari, description: ""}},
      {"trello.card.update", %{"card_id" => @card_ari, "description" => ""},
       %{card_id: @card_ari, description: ""}},
      {"trello.card.move", %{card_id: @card_ari, list_id: @list_ari},
       %{card_id: @card_ari, list_id: @list_ari, position: nil}},
      {"trello.card.complete", %{card_id: @card_ari}, %{card_id: @card_ari}},
      {"trello.card.archive", %{card_id: @card_ari}, %{card_id: @card_ari}},
      {"trello.card.label.attach", %{card_id: @card_ari, label_id: label_ari()},
       %{card_id: @card_ari, label_id: label_ari()}},
      {"trello.card.label.detach", %{card_id: @card_ari, label_id: label_ari()},
       %{card_id: @card_ari, label_id: label_ari()}},
      {"trello.checklist.list", %{card_id: @card_ari},
       %{card_id: @card_ari, cursor: nil, limit: 25}},
      {"trello.checklist.create", %{card_id: @card_ari, name: "Steps"},
       %{card_id: @card_ari, name: "Steps", position: nil}},
      {"trello.checklist.update",
       %{card_id: @card_ari, checklist_id: @checklist_ari, position: 0},
       %{card_id: @card_ari, checklist_id: @checklist_ari, position: 0}},
      {"trello.checklist.item.create",
       %{card_id: @card_ari, checklist_id: @checklist_ari, text: "Verify"},
       %{card_id: @card_ari, checklist_id: @checklist_ari, text: "Verify", position: nil}},
      {"trello.checklist.item.update",
       %{card_id: @card_ari, checklist_id: @checklist_ari, item_id: @item_ari, checked: false},
       %{
         card_id: @card_ari,
         checklist_id: @checklist_ari,
         item_id: @item_ari,
         checked: false
       }},
      {"trello.checklist.item.update",
       %{
         "card_id" => @card_ari,
         "checklist_id" => @checklist_ari,
         "item_id" => @item_ari,
         "checked" => false
       },
       %{
         card_id: @card_ari,
         checklist_id: @checklist_ari,
         item_id: @item_ari,
         checked: false
       }}
    ]

    for {action, input, expected} <- cases do
      assert {:ok, ^expected} = Input.validate(action, input)
    end
  end

  test "rejects bounds, malformed ARIs, empty updates, and override keys" do
    invalid = [
      {"trello.board.get", %{endpoint_id: "evil"}},
      {"trello.board.get", %{tool_name: "mcp.tools.call"}},
      {"trello.board.get", %{action: "list_labels"}},
      {"trello.list.list", %{limit: 0}},
      {"trello.label.list", %{limit: 101}},
      {"trello.card.list", %{state: "closed"}},
      {"trello.card.get", %{id: "card-id"}},
      {"trello.card.search", %{query: String.duplicate("q", 501)}},
      {"trello.card.create", %{list_id: @list_ari, name: String.duplicate("n", 513)}},
      {"trello.card.create",
       %{list_id: @list_ari, name: "Card", due: "2026-08-20T12:00:00-05:00"}},
      {"trello.card.update", %{card_id: @card_ari}},
      {"trello.card.move", %{card_id: @card_ari, list_id: @list_ari, position: -1}},
      {"trello.checklist.update", %{card_id: @card_ari, checklist_id: @checklist_ari}},
      {"trello.checklist.item.create",
       %{card_id: @card_ari, checklist_id: @checklist_ari, text: "   "}},
      {"trello.checklist.item.update",
       %{card_id: @card_ari, checklist_id: @checklist_ari, item_id: @item_ari}},
      {"trello.card.archive", %{card_id: String.replace(@card_ari, "card", "list")}}
    ]

    for {action, input} <- invalid do
      assert {:error, %Error.ValidationError{reason: :invalid_trello_input}} =
               Input.validate(action, input)
    end
  end

  test "validates exact board identity and exact hosted endpoint without exposing secrets" do
    runtime = runtime()

    assert {:ok, identity} = BoardIdentity.from_runtime(runtime)
    assert identity.board_name == "Decentra Finance"
    assert identity.board_url == "https://trello.com/b/Z4Htjzwu/decentra-finance"
    assert identity.board_ari == @board_ari
    assert identity.workspace_object_id == @workspace_id
    assert :ok = BoardIdentity.validate_endpoint(runtime.credential_lease)

    invalid_runtimes = [
      put_in(
        runtime.context.connection.metadata[:board_ari],
        "ari:cloud:trello::board/workspace/#{@workspace_id}/aaaaaaaaaaaaaaaaaaaaaaaa"
      ),
      put_in(
        runtime.context.connection.metadata[:board_url],
        "https://evil.example/b/Z4Htjzwu/x"
      ),
      put_in(runtime.context.connection.metadata[:board_short_id], "bad"),
      put_in(runtime.context.connection.metadata[:board_name], " Decentra Finance"),
      put_in(runtime.context.connection.provider, :mcp),
      put_in(runtime.context.connection.profile, :endpoint),
      put_in(runtime.context.connection.owner_type, :tenant),
      put_in(runtime.context.connection.metadata[:mcp_endpoint_id], "caller-selected")
    ]

    for invalid <- invalid_runtimes do
      assert {:error, %Error.AuthError{}} = BoardIdentity.from_runtime(invalid)
    end

    bad_endpoint =
      put_in(
        runtime.credential_lease.fields[:mcp_endpoint].transport,
        {:streamable_http,
         [url: "https://evil.example/v1", headers: [{"authorization", "Bearer secret-token"}]]}
      )

    assert {:error, %Error.AuthError{} = error} =
             BoardIdentity.validate_endpoint(bad_endpoint.credential_lease)

    rendered = inspect(error) <> inspect(Error.to_map(error))
    refute rendered =~ "secret-token"
    refute rendered =~ "evil.example"

    for url <- [
          "https://mcp.trello.com/v1?endpoint=other",
          "https://mcp.trello.com/v1#other",
          "https://mcp.trello.com/v2"
        ] do
      endpoint_override =
        put_in(
          runtime.credential_lease.fields[:mcp_endpoint].transport,
          {:streamable_http, [url: url, headers: [{"authorization", "Bearer secret-token"}]]}
        )

      assert {:error, %Error.AuthError{reason: :trello_mcp_endpoint_mismatch}} =
               BoardIdentity.validate_endpoint(endpoint_override.credential_lease)
    end
  end

  defp runtime do
    connection =
      Connection.new!(%{
        id: "trello-1",
        provider: :trello,
        profile: :oauth_user,
        tenant_id: "tenant-1",
        owner_type: :user,
        owner_id: "user-1",
        subject: %{id: "trello-user-1"},
        status: :connected,
        scopes: ["trello:read", "trello:write", "trello:search"],
        metadata: %{
          mcp_endpoint_id: "trello",
          connection_revision: 1,
          board_name: "Decentra Finance",
          board_url: "https://trello.com/b/Z4Htjzwu/decentra-finance",
          board_ari: @board_ari,
          board_object_id: @board_object_id,
          board_short_id: "Z4Htjzwu",
          workspace_object_id: @workspace_id
        }
      })

    lease =
      CredentialLease.from_connection!(
        connection,
        %{
          mcp_endpoint: %{
            transport:
              {:streamable_http,
               [
                 url: "https://mcp.trello.com/v1",
                 headers: [{"authorization", "Bearer secret-token"}]
               ]},
            client_info: %{name: "trello-test"}
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        metadata: %{credential_version: 1}
      )

    %{
      context:
        Context.new!(%{
          tenant_id: "tenant-1",
          actor: %{id: "user-1", type: :user},
          connection: connection
        }),
      credential_lease: lease,
      credentials: lease.fields
    }
  end

  defp label_ari,
    do: "ari:cloud:trello::label/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6722"
end
