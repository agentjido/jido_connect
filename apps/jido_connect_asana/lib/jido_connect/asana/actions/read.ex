defmodule Jido.Connect.Asana.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Asana.ScopeResolver

  actions do
    # ---------------------------------------------------------------------------
    # Workspaces
    # ---------------------------------------------------------------------------

    action :list_workspaces do
      id("asana.workspace.list")
      resource(:workspace)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List workspaces")
      description("List Asana workspaces and organizations accessible to the user.")
      handler(Jido.Connect.Asana.Handlers.Actions.ListWorkspaces)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default"], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer,
          default: nil,
          description: "Results per page (1-100)."
        )

        field(:offset, :string,
          default: nil,
          description: "Offset token from a previous response."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Projects
    # ---------------------------------------------------------------------------

    action :list_projects do
      id("asana.project.list")
      resource(:project)
      verb(:list)
      data_classification(:workspace_content)
      label("List projects")
      description("List Asana projects, optionally filtered by workspace or team.")
      handler(Jido.Connect.Asana.Handlers.Actions.ListProjects)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:workspace, :string,
          default: nil,
          description: "Workspace GID to filter projects."
        )

        field(:team, :string,
          default: nil,
          description: "Team GID to filter projects."
        )

        field(:archived, :boolean,
          default: nil,
          description: "Filter by archived state."
        )

        field(:limit, :integer,
          default: nil,
          description: "Results per page (1-100)."
        )

        field(:offset, :string,
          default: nil,
          description: "Offset token from a previous response."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Tasks
    # ---------------------------------------------------------------------------

    action :list_tasks do
      id("asana.task.list")
      resource(:task)
      verb(:list)
      data_classification(:workspace_content)
      label("List tasks")
      description("List Asana tasks, optionally filtered by project, workspace, or assignee.")
      handler(Jido.Connect.Asana.Handlers.Actions.ListTasks)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:project, :string,
          default: nil,
          description: "Project GID to filter tasks."
        )

        field(:workspace, :string,
          default: nil,
          description: "Workspace GID to filter tasks."
        )

        field(:assignee, :string,
          default: nil,
          description: "User GID to filter tasks by assignee."
        )

        field(:completed_since, :string,
          default: nil,
          description: "ISO 8601 datetime to filter tasks completed after."
        )

        field(:limit, :integer,
          default: nil,
          description: "Results per page (1-100)."
        )

        field(:offset, :string,
          default: nil,
          description: "Offset token from a previous response."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :get_task do
      id("asana.task.get")
      resource(:task)
      verb(:get)
      data_classification(:workspace_content)
      label("Get task")
      description("Retrieve a single Asana task by GID with full details.")
      handler(Jido.Connect.Asana.Handlers.Actions.GetTask)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID."
        )
      end

      output do
        field(:task, :map)
      end
    end

    action :search_tasks do
      id("asana.task.search")
      resource(:task)
      verb(:search)
      data_classification(:workspace_content)
      label("Search tasks")
      description("Search Asana tasks in a workspace using text and structured filters.")
      handler(Jido.Connect.Asana.Handlers.Actions.SearchTasks)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:workspace_gid, :string,
          required?: true,
          description: "Workspace GID to search within."
        )

        field(:query, :string,
          default: nil,
          description: "Full-text search query."
        )

        field(:assignee, :string,
          default: nil,
          description: "User GID to filter by assignee."
        )

        field(:projects, :string,
          default: nil,
          description: "Comma-separated project GIDs to filter by."
        )

        field(:completed, :boolean,
          default: nil,
          description: "Filter by completion state."
        )

        field(:due_before, :string,
          default: nil,
          description: "ISO 8601 date to filter tasks due before."
        )

        field(:due_after, :string,
          default: nil,
          description: "ISO 8601 date to filter tasks due after."
        )

        field(:limit, :integer,
          default: nil,
          description: "Results per page (1-100)."
        )

        field(:offset, :string,
          default: nil,
          description: "Offset token from a previous response."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Stories
    # ---------------------------------------------------------------------------

    action :list_stories do
      id("asana.story.list")
      resource(:story)
      verb(:list)
      data_classification(:workspace_content)
      label("List stories")
      description("List stories (comments and activity) for an Asana task.")
      handler(Jido.Connect.Asana.Handlers.Actions.ListStories)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID."
        )

        field(:limit, :integer,
          default: nil,
          description: "Results per page (1-100)."
        )

        field(:offset, :string,
          default: nil,
          description: "Offset token from a previous response."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Users
    # ---------------------------------------------------------------------------

    action :get_user do
      id("asana.user.get")
      resource(:user)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get user")
      description("Retrieve a single Asana user by GID.")
      handler(Jido.Connect.Asana.Handlers.Actions.GetUser)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:user_gid, :string,
          required?: true,
          description: "Asana user GID."
        )
      end

      output do
        field(:user, :map)
      end
    end

    action :list_users do
      id("asana.user.list")
      resource(:user)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List users")
      description("List Asana users, optionally filtered by workspace.")
      handler(Jido.Connect.Asana.Handlers.Actions.ListUsers)
      effect(:read)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      input do
        field(:workspace, :string,
          default: nil,
          description: "Workspace GID to filter users."
        )

        field(:limit, :integer,
          default: nil,
          description: "Results per page (1-100)."
        )

        field(:offset, :string,
          default: nil,
          description: "Offset token from a previous response."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end
  end
end
