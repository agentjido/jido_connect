defmodule Jido.Connect.Notion.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Notion.ScopeResolver

  actions do
    action :search do
      id("notion.search")
      resource(:search_result)
      verb(:list)
      data_classification(:workspace_content)
      label("Search Notion")
      description("Search pages and databases in a Notion workspace.")
      handler(Jido.Connect.Notion.Handlers.Actions.Search)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_content"], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, description: "Search query text.")

        field(:filter, :map,
          description: "Filter by object type, e.g. %{property: \"object\", value: \"page\"}."
        )

        field(:sort, :map,
          description:
            "Sort direction, e.g. %{direction: \"ascending\", timestamp: \"last_edited_time\"}."
        )

        field(:start_cursor, :string, description: "Pagination cursor from a previous response.")

        field(:page_size, :integer, description: "Number of results per page (1-100).")
      end

      output do
        field(:results, {:array, :map})
        field(:has_more, :boolean)
        field(:next_cursor, :string)
      end
    end

    action :get_page do
      id("notion.page.get")
      resource(:page)
      verb(:get)
      data_classification(:workspace_content)
      label("Get page")
      description("Retrieve a Notion page by ID.")
      handler(Jido.Connect.Notion.Handlers.Actions.GetPage)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_content"], resolver: @scope_resolver)
      end

      input do
        field(:page_id, :string, required?: true, description: "Notion page ID.")
      end

      output do
        field(:page, :map)
      end
    end

    action :get_database do
      id("notion.database.get")
      resource(:database)
      verb(:get)
      data_classification(:workspace_content)
      label("Get database")
      description("Retrieve a Notion database by ID.")
      handler(Jido.Connect.Notion.Handlers.Actions.GetDatabase)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_content", "read_databases"], resolver: @scope_resolver)
      end

      input do
        field(:database_id, :string, required?: true, description: "Notion database ID.")
      end

      output do
        field(:database, :map)
      end
    end

    action :query_database do
      id("notion.database.query")
      resource(:database_page)
      verb(:list)
      data_classification(:workspace_content)
      label("Query database")
      description("Query a Notion database with optional filters and sorts.")
      handler(Jido.Connect.Notion.Handlers.Actions.QueryDatabase)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_content", "read_databases"], resolver: @scope_resolver)
      end

      input do
        field(:database_id, :string, required?: true, description: "Notion database ID.")

        field(:filter, :map, description: "Notion filter compound or simple filter object.")

        field(:sorts, {:array, :map}, description: "List of sort objects.")

        field(:start_cursor, :string, description: "Pagination cursor from a previous response.")

        field(:page_size, :integer, description: "Number of results per page (1-100).")
      end

      output do
        field(:results, {:array, :map})
        field(:has_more, :boolean)
        field(:next_cursor, :string)
      end
    end

    action :retrieve_block do
      id("notion.block.get")
      resource(:block)
      verb(:get)
      data_classification(:workspace_content)
      label("Retrieve block")
      description("Retrieve a Notion block by ID.")
      handler(Jido.Connect.Notion.Handlers.Actions.RetrieveBlock)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_content"], resolver: @scope_resolver)
      end

      input do
        field(:block_id, :string, required?: true, description: "Notion block ID.")
      end

      output do
        field(:block, :map)
      end
    end

    action :list_block_children do
      id("notion.block.list_children")
      resource(:block)
      verb(:list)
      data_classification(:workspace_content)
      label("List block children")
      description("List child blocks of a Notion block or page.")
      handler(Jido.Connect.Notion.Handlers.Actions.ListBlockChildren)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_content"], resolver: @scope_resolver)
      end

      input do
        field(:block_id, :string, required?: true, description: "Notion block or page ID.")

        field(:start_cursor, :string, description: "Pagination cursor from a previous response.")

        field(:page_size, :integer, description: "Number of results per page (1-100).")
      end

      output do
        field(:results, {:array, :map})
        field(:has_more, :boolean)
        field(:next_cursor, :string)
      end
    end

    action :list_comments do
      id("notion.comment.list")
      resource(:comment)
      verb(:list)
      data_classification(:workspace_content)
      label("List comments")
      description("List comments on a Notion block or page.")
      handler(Jido.Connect.Notion.Handlers.Actions.ListComments)
      effect(:read)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["read_comments"], resolver: @scope_resolver)
      end

      input do
        field(:block_id, :string, required?: true, description: "Notion block or page ID.")

        field(:start_cursor, :string, description: "Pagination cursor from a previous response.")

        field(:page_size, :integer, description: "Number of results per page (1-100).")
      end

      output do
        field(:results, {:array, :map})
        field(:has_more, :boolean)
        field(:next_cursor, :string)
      end
    end
  end
end
