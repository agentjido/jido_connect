defmodule Jido.Connect.Trello do
  @moduledoc """
  Reviewed Trello work-board actions over the official hosted Trello MCP server.

  The integration fixes the hosted endpoint, remote MCP tool, remote action,
  workspace, and board at provider-owned boundaries. Action input cannot select
  these transport or identity values.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Trello.Actions.Boards,
      Jido.Connect.Trello.Actions.Lists,
      Jido.Connect.Trello.Actions.Cards,
      Jido.Connect.Trello.Actions.Checklists
    ]

  defdelegate catalog_packs, to: Jido.Connect.Trello.CatalogPacks, as: :all

  integration do
    id(:trello)
    name("Trello")
    description("Reviewed Trello board, list, card, label, and checklist tools.")
    category(:productivity)

    docs([
      "https://support.atlassian.com/trello/docs/connect-trello-to-ai-assistants-with-trello-mcp/"
    ])
  end

  catalog do
    package(:jido_connect_trello)
    status(:experimental)
    tags([:productivity, :project_management, :collaboration, :mcp])

    metadata(%{
      transport: :mcp,
      endpoint: "https://mcp.trello.com/v1",
      typed_actions_only?: true
    })
  end

  auth do
    oauth2 :oauth_user do
      default?(true)
      owner(:user)
      subject(:user)
      label("Trello hosted MCP OAuth user")
      authorize_url("https://mcp.trello.com/v1")
      token_url("https://mcp.trello.com/v1")
      callback_path("/integrations/trello/oauth/callback")
      setup(:hosted_mcp_oauth)
      refresh_token_field(:refresh_token)
      credential_fields([:mcp_endpoint, :refresh_token, :oauth_client])
      lease_fields([:mcp_endpoint])
      scopes(["trello:read", "trello:write", "trello:search"])
      default_scopes(["trello:read", "trello:write", "trello:search"])
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end
end
