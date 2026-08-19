defmodule Jido.Connect.X.Actions.Reads do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.X.Contract

  actions do
    action :get_account do
      id("x.account.get")
      resource(:social_account)
      verb(:get)
      data_classification(:personal_data)
      label("Get X account")
      description("Get the authenticated X account after username verification.")
      handler(Jido.Connect.X.Handlers.Action)
      effect(:read)

      access do
        auth([:local_mcp], default: :local_mcp)
        scopes(["users.read"])
      end

      output do
        field(:kind, :string)
        field(:id, :string)
        field(:username, :string)
        field(:name, :string)
      end
    end

    action :list_bookmarks do
      id("x.bookmark.list")
      resource(:social_bookmark)
      verb(:list)
      data_classification(:personal_data)
      label("List X bookmarks")
      description("List bookmarks for the verified authenticated X account.")
      handler(Jido.Connect.X.Handlers.Action)
      effect(:read)

      access do
        auth([:local_mcp], default: :local_mcp)
        scopes(["tweet.read", "users.read", "bookmark.read"])
      end

      input do
        field(:max_results, :integer, default: 20, minimum: 1, maximum: 100)

        field(:pagination_token, :string,
          min_length: 1,
          max_length: Contract.pagination_token_max()
        )
      end

      output do
        field(:kind, :string)
        field(:account, :map)
        field(:count, :integer)
        field(:limit, :integer)
        field(:next_cursor, :string)
        field(:items, {:array, :map})
      end
    end

    action :list_posts do
      id("x.post.list")
      resource(:social_post)
      verb(:list)
      data_classification(:personal_data)
      label("List X posts")
      description("List posts for the verified authenticated X account.")
      handler(Jido.Connect.X.Handlers.Action)
      effect(:read)

      access do
        auth([:local_mcp], default: :local_mcp)
        scopes(["tweet.read", "users.read"])
      end

      input do
        field(:max_results, :integer, default: 5, minimum: 5, maximum: 100)

        field(:pagination_token, :string,
          min_length: 1,
          max_length: Contract.pagination_token_max()
        )
      end

      output do
        field(:kind, :string)
        field(:account, :map)
        field(:count, :integer)
        field(:limit, :integer)
        field(:next_cursor, :string)
        field(:items, {:array, :map})
      end
    end
  end
end
