defmodule Jido.Connect.Jira.Actions.Projects do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver

  actions do
    action :list_projects do
      id("jira.project.list")
      resource(:project)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List projects")
      description("List Jira projects visible to the authenticated user.")
      handler(Jido.Connect.Jira.Handlers.Actions.ListProjects)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work", "read:jira-configuration"], resolver: @scope_resolver)
      end

      input do
        field(:start_at, :integer, default: 0)
        field(:max_results, :integer, default: 50)
      end

      output do
        field(:projects, {:array, :map})
        field(:total, :integer)
        field(:start_at, :integer)
        field(:max_results, :integer)
        field(:is_last, :boolean)
      end
    end

    action :get_project do
      id("jira.project.get")
      resource(:project)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get project")
      description("Fetch a Jira project by key or ID.")
      handler(Jido.Connect.Jira.Handlers.Actions.GetProject)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work", "read:jira-configuration"], resolver: @scope_resolver)
      end

      input do
        field(:project_key, :string, required?: true, example: "PROJ")
      end

      output do
        field(:key, :string)
        field(:name, :string)
        field(:id, :string)
        field(:project_type, :string)
        field(:style, :string)
        field(:lead, :map)
        field(:description, :string)
      end
    end
  end
end
