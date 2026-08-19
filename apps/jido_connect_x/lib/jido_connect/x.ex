defmodule Jido.Connect.X do
  @moduledoc """
  Reviewed X account, bookmark, and post reads over the official local XMCP server.

  The integration fixes the loopback endpoint and remote tools at provider-owned
  boundaries. Each request verifies the authenticated X username before it
  returns account data or sends the verified account ID to another tool.
  """

  use Jido.Connect, fragments: [Jido.Connect.X.Actions.Reads]

  alias Jido.Connect.X.Contract

  defdelegate catalog_packs, to: Jido.Connect.X.CatalogPacks, as: :all

  integration do
    id(:x)
    name("X")
    description("Reviewed read-only X account, bookmark, and post tools.")
    category(:social)
    docs(["https://docs.x.com/tools/mcp"])
  end

  catalog do
    package(:jido_connect_x)
    status(:experimental)
    tags([:social, :posts, :bookmarks, :mcp])

    metadata(%{
      transport: :mcp,
      endpoint: Contract.endpoint(),
      local_only?: true,
      typed_actions_only?: true
    })
  end

  auth do
    api_key :local_mcp do
      default?(true)
      owner(:user)
      subject(:user)
      label("Local XMCP account")
      setup(:local_xmcp)
      credential_fields([:mcp_endpoint])
      lease_fields([:mcp_endpoint])
      scopes(["tweet.read", "users.read", "bookmark.read"])
      default_scopes(["tweet.read", "users.read", "bookmark.read"])
    end
  end
end
