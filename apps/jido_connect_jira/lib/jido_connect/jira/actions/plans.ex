defmodule Jido.Connect.Jira.Actions.Plans do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver
  @max_id 2_147_483_647

  actions do
    action :list_plans do
      id("jira.plan.list")
      resource(:plan)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List plans")
      description("List Jira plans with a bounded cursor page.")
      handler(Jido.Connect.Jira.Handlers.Actions.ListPlans)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:include_archived, :boolean, default: false)
        field(:include_trashed, :boolean, default: false)
        field(:limit, :integer, default: 50, minimum: 1, maximum: 100)
        field(:cursor, :string, min_length: 1, max_length: 1_000)
      end

      output do
        field(:plans, {:array, :map})
        field(:total, :integer)
        field(:limit, :integer)
        field(:next_cursor, :string)
        field(:is_last, :boolean)
      end
    end

    action :get_plan do
      id("jira.plan.get")
      resource(:plan)
      verb(:get)
      data_classification(:workspace_content)
      label("Get plan")
      description("Get one Jira plan by ID.")
      handler(Jido.Connect.Jira.Handlers.Actions.GetPlan)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:status, :string)
        field(:scenario_id, :string)
        field(:last_saved_at, :string)
        field(:lead_account_id, :string)
        field(:issue_sources, {:array, :map})
        field(:scheduling, :map)
        field(:exclusion_rules, :map)
        field(:cross_project_releases, {:array, :map})
        field(:custom_fields, {:array, :map})
        field(:permissions, {:array, :map})
      end
    end

    action :create_plan do
      id("jira.plan.create")
      resource(:plan)
      verb(:create)
      data_classification(:workspace_content)
      label("Create plan")
      description("Create a Jira plan. Jira administration access is required.")
      handler(Jido.Connect.Jira.Handlers.Actions.CreatePlan)
      preview(Jido.Connect.Jira.Previews.CreatePlan)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
        field(:lead_account_id, :string, min_length: 1, max_length: 255)
        field(:issue_sources, {:array, :map}, required?: true, min_length: 1, max_length: 100)
        field(:scheduling, :map, required?: true)
        field(:exclusion_rules, :map)
        field(:cross_project_releases, {:array, :map}, max_length: 100)
        field(:custom_fields, {:array, :map}, max_length: 100)
        field(:permissions, {:array, :map}, max_length: 100)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:created, :boolean)
      end
    end

    action :update_plan do
      id("jira.plan.update")
      resource(:plan)
      verb(:update)
      data_classification(:workspace_content)
      label("Update plan")
      description("Update selected fields on one Jira plan.")
      handler(Jido.Connect.Jira.Handlers.Actions.UpdatePlan)
      preview(Jido.Connect.Jira.Previews.UpdatePlan)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
        field(:name, :string, min_length: 1, max_length: 255)
        field(:lead_account_id, :string, min_length: 1, max_length: 255)
        field(:issue_sources, {:array, :map}, min_length: 1, max_length: 100)
        field(:scheduling, :map)
        field(:exclusion_rules, :map)
        field(:cross_project_releases, {:array, :map}, max_length: 100)
        field(:custom_fields, {:array, :map}, max_length: 100)
        field(:permissions, {:array, :map}, max_length: 100)
      end

      output do
        field(:id, :string)
        field(:updated, :boolean)
        field(:changed_fields, {:array, :string})
      end
    end

    action :duplicate_plan do
      id("jira.plan.duplicate")
      resource(:plan)
      verb(:create)
      data_classification(:workspace_content)
      label("Duplicate plan")
      description("Duplicate one Jira plan with a new name.")
      handler(Jido.Connect.Jira.Handlers.Actions.DuplicatePlan)
      preview(Jido.Connect.Jira.Previews.DuplicatePlan)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
      end

      output do
        field(:id, :string)
        field(:source_plan_id, :string)
        field(:name, :string)
        field(:duplicated, :boolean)
      end
    end

    action :archive_plan do
      id("jira.plan.archive")
      resource(:plan)
      verb(:archive)
      data_classification(:workspace_content)
      label("Archive plan")
      description("Archive one Jira plan.")
      handler(Jido.Connect.Jira.Handlers.Actions.ArchivePlan)
      preview(Jido.Connect.Jira.Previews.ArchivePlan)
      effect(:destructive, confirmation: :always)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
      end

      output do
        field(:id, :string)
        field(:updated, :boolean)
      end
    end

    action :trash_plan do
      id("jira.plan.trash")
      resource(:plan)
      verb(:delete)
      data_classification(:workspace_content)
      label("Trash plan")
      description("Move one Jira plan to trash.")
      handler(Jido.Connect.Jira.Handlers.Actions.TrashPlan)
      preview(Jido.Connect.Jira.Previews.TrashPlan)
      effect(:destructive, confirmation: :always)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:jira_admin_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
      end

      output do
        field(:id, :string)
        field(:updated, :boolean)
      end
    end
  end
end
