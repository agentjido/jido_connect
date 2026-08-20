defmodule Jido.Connect.Bitbucket do
  @moduledoc """
  Bitbucket Cloud integration authored with the `Jido.Connect` Spark DSL.

  The provider has a distinct `:bitbucket` identity and exposes only reviewed
  Bitbucket actions.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Bitbucket.Actions.PullRequests
    ]

  defdelegate catalog_packs, to: Jido.Connect.Bitbucket.CatalogPacks, as: :all

  integration do
    id(:bitbucket)
    name("Bitbucket")
    description("Reviewed Bitbucket Cloud repository and pull-request tools.")
    category(:developer_tools)
    docs(["https://developer.atlassian.com/cloud/bitbucket/rest/api-group-pullrequests/"])
  end

  catalog do
    package(:jido_connect_bitbucket)
    status(:experimental)
    tags([:source_control, :code_review, :developer_tools])
  end

  auth do
    api_key :api_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Bitbucket API token")
      setup(:api_token_basic_auth)
      credential_fields([:email, :api_token])
      lease_fields([:email, :api_token])
      scopes(["read:pullrequest:bitbucket"])
      default_scopes(["read:pullrequest:bitbucket"])
    end
  end
end
