defmodule Jido.Connect.Confluence do
  @moduledoc """
  Confluence Cloud integration authored with the `Jido.Connect` Spark DSL.

  The package has a distinct `:confluence` provider identity and exposes only
  the reviewed space and page actions.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Confluence.Actions.Spaces,
      Jido.Connect.Confluence.Actions.Pages
    ]

  defdelegate catalog_packs, to: Jido.Connect.Confluence.CatalogPacks, as: :all

  integration do
    id(:confluence)
    name("Confluence")
    description("Reviewed Confluence Cloud space and page tools.")
    category(:productivity)
    docs(["https://developer.atlassian.com/cloud/confluence/rest/v2/"])
  end

  catalog do
    package(:jido_connect_confluence)
    status(:experimental)
    tags([:productivity, :knowledge_management, :collaboration])
  end

  auth do
    api_key :api_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Confluence API token")
      setup(:api_token_basic_auth)
      credential_fields([:email, :api_token])
      lease_fields([:email, :api_token])
      scopes(["read:space:confluence", "read:page:confluence", "write:page:confluence"])
      default_scopes(["read:space:confluence", "read:page:confluence", "write:page:confluence"])
    end
  end
end
