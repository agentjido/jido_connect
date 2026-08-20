defmodule Jido.Connect.Jira.Actions.Filters do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver
  @max_id 2_147_483_647

  actions do
    action :list_filters do
      id("jira.filter.list")
      resource(:filter)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List filters")
      description("List Jira saved filters with bounded paging.")
      handler(Jido.Connect.Jira.Handlers.Actions.ListFilters)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, min_length: 1, max_length: 255)
        field(:owner_account_id, :string, min_length: 1, max_length: 255)
        field(:limit, :integer, default: 50, minimum: 1, maximum: 100)
        field(:offset, :integer, default: 0, minimum: 0, maximum: @max_id)
      end

      output do
        field(:filters, {:array, :map})
        field(:total, :integer)
        field(:offset, :integer)
        field(:limit, :integer)
        field(:is_last, :boolean)
      end
    end

    action :get_filter do
      id("jira.filter.get")
      resource(:filter)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get filter")
      description("Get one Jira saved filter by ID.")
      handler(Jido.Connect.Jira.Handlers.Actions.GetFilter)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:query, :string)
        field(:description, :string)
        field(:favorite, :boolean)
        field(:owner, :map)
        field(:share_count, :integer)
        field(:url, :string)
      end
    end

    action :create_filter do
      id("jira.filter.create")
      resource(:filter)
      verb(:create)
      data_classification(:workspace_content)
      label("Create filter")
      description("Create a Jira saved filter.")
      handler(Jido.Connect.Jira.Handlers.Actions.CreateFilter)
      preview(Jido.Connect.Jira.Previews.CreateFilter)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
        field(:query, :string, required?: true, min_length: 1, max_length: 20_000)
        field(:description, :string, max_length: 32_768)
        field(:favorite, :boolean, default: false)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:query, :string)
        field(:description, :string)
        field(:favorite, :boolean)
        field(:owner, :map)
        field(:share_count, :integer)
        field(:url, :string)
      end
    end

    action :update_filter do
      id("jira.filter.update")
      resource(:filter)
      verb(:update)
      data_classification(:workspace_content)
      label("Update filter")
      description("Update a Jira saved filter.")
      handler(Jido.Connect.Jira.Handlers.Actions.UpdateFilter)
      preview(Jido.Connect.Jira.Previews.UpdateFilter)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
        field(:query, :string, required?: true, min_length: 1, max_length: 20_000)
        field(:description, :string, max_length: 32_768)
        field(:favorite, :boolean)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:query, :string)
        field(:description, :string)
        field(:favorite, :boolean)
        field(:owner, :map)
        field(:share_count, :integer)
        field(:url, :string)
      end
    end

    action :get_filter_columns do
      id("jira.filter.columns.get")
      resource(:filter_columns)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get filter columns")
      description("Get the Jira List View columns for one saved filter.")
      handler(Jido.Connect.Jira.Handlers.Actions.GetFilterColumns)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
      end

      output do
        field(:filter_id, :string)
        field(:columns, {:array, :map})
      end
    end

    action :update_filter_columns do
      id("jira.filter.columns.update")
      resource(:filter_columns)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update filter columns")
      description("Replace the Jira List View columns for one saved filter.")
      handler(Jido.Connect.Jira.Handlers.Actions.UpdateFilterColumns)
      preview(Jido.Connect.Jira.Previews.UpdateFilterColumns)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
        field(:columns, {:array, :string}, required?: true, min_length: 1, max_length: 100)
      end

      output do
        field(:filter_id, :string)
        field(:columns, {:array, :map})
        field(:updated, :boolean)
      end
    end

    action :update_filter_share do
      id("jira.filter.share.update")
      resource(:filter_share)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update filter sharing")
      description("Replace all share permissions for one Jira saved filter.")
      handler(Jido.Connect.Jira.Handlers.Actions.UpdateFilterShare)
      preview(Jido.Connect.Jira.Previews.UpdateFilterShare)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)

        field(:scope, :string,
          required?: true,
          enum: ["private", "authenticated", "public", "projects", "groups"]
        )

        field(:projects, {:array, :string}, min_length: 1, max_length: 100)
        field(:group_ids, {:array, :string}, min_length: 1, max_length: 100)
      end

      output do
        field(:filter_id, :string)
        field(:scope, :string)
        field(:permissions, {:array, :map})
        field(:updated, :boolean)
      end
    end
  end
end
