defmodule Jido.Connect.Asana.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Asana.ScopeResolver

  actions do
    # ---------------------------------------------------------------------------
    # Task create / update
    # ---------------------------------------------------------------------------

    action :create_task do
      id("asana.task.create")
      resource(:task)
      verb(:create)
      data_classification(:workspace_content)
      label("Create task")
      description("Create a new Asana task in a workspace.")
      handler(Jido.Connect.Asana.Handlers.Actions.CreateTask)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string,
          required?: true,
          description: "Name of the task."
        )

        field(:workspace_gid, :string,
          required?: true,
          description: "Workspace GID where the task will be created."
        )

        field(:notes, :string,
          default: nil,
          description: "Free-form textual description."
        )

        field(:assignee, :string,
          default: nil,
          description: "User GID to assign the task to."
        )

        field(:due_on, :string,
          default: nil,
          description: "ISO 8601 date when the task is due."
        )

        field(:due_at, :string,
          default: nil,
          description: "ISO 8601 datetime when the task is due."
        )

        field(:start_on, :string,
          default: nil,
          description: "ISO 8601 date when work on the task starts."
        )

        field(:projects, {:array, :string},
          default: nil,
          description: "List of project GIDs to add the task to."
        )

        field(:tags, {:array, :string},
          default: nil,
          description: "List of tag GIDs to add to the task."
        )

        field(:parent, :string,
          default: nil,
          description: "Parent task GID to create a subtask."
        )
      end

      output do
        field(:task, :map)
      end
    end

    action :update_task do
      id("asana.task.update")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Update task")
      description("Update an existing Asana task by GID.")
      handler(Jido.Connect.Asana.Handlers.Actions.UpdateTask)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID to update."
        )

        field(:name, :string,
          default: nil,
          description: "New name for the task."
        )

        field(:notes, :string,
          default: nil,
          description: "Free-form textual description."
        )

        field(:assignee, :string,
          default: nil,
          description: "User GID to assign the task to."
        )

        field(:due_on, :string,
          default: nil,
          description: "ISO 8601 date when the task is due."
        )

        field(:due_at, :string,
          default: nil,
          description: "ISO 8601 datetime when the task is due."
        )

        field(:start_on, :string,
          default: nil,
          description: "ISO 8601 date when work on the task starts."
        )

        field(:completed, :boolean,
          default: nil,
          description: "Mark the task complete or incomplete."
        )
      end

      output do
        field(:task, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Complete / uncomplete shortcuts
    # ---------------------------------------------------------------------------

    action :complete_task do
      id("asana.task.complete")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Complete task")
      description("Mark an Asana task as completed.")
      handler(Jido.Connect.Asana.Handlers.Actions.CompleteTask)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID to complete."
        )
      end

      output do
        field(:task, :map)
      end
    end

    action :uncomplete_task do
      id("asana.task.uncomplete")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Uncomplete task")
      description("Mark an Asana task as not completed.")
      handler(Jido.Connect.Asana.Handlers.Actions.UncompleteTask)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID to uncomplete."
        )
      end

      output do
        field(:task, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Project and tag associations
    # ---------------------------------------------------------------------------

    action :add_task_project do
      id("asana.task.add_project")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Add task to project")
      description("Add an existing task to a project.")
      handler(Jido.Connect.Asana.Handlers.Actions.AddTaskProject)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID."
        )

        field(:project_gid, :string,
          required?: true,
          description: "Project GID to add the task to."
        )
      end

      output do
        field(:result, :map)
      end
    end

    action :remove_task_project do
      id("asana.task.remove_project")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Remove task from project")
      description("Remove a task from a project.")
      handler(Jido.Connect.Asana.Handlers.Actions.RemoveTaskProject)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID."
        )

        field(:project_gid, :string,
          required?: true,
          description: "Project GID to remove the task from."
        )
      end

      output do
        field(:result, :map)
      end
    end

    action :add_task_tag do
      id("asana.task.add_tag")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Add tag to task")
      description("Add a tag to an Asana task.")
      handler(Jido.Connect.Asana.Handlers.Actions.AddTaskTag)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID."
        )

        field(:tag_gid, :string,
          required?: true,
          description: "Tag GID to add to the task."
        )
      end

      output do
        field(:result, :map)
      end
    end

    action :remove_task_tag do
      id("asana.task.remove_tag")
      resource(:task)
      verb(:update)
      data_classification(:workspace_content)
      label("Remove tag from task")
      description("Remove a tag from an Asana task.")
      handler(Jido.Connect.Asana.Handlers.Actions.RemoveTaskTag)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID."
        )

        field(:tag_gid, :string,
          required?: true,
          description: "Tag GID to remove from the task."
        )
      end

      output do
        field(:result, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Story / comment
    # ---------------------------------------------------------------------------

    action :create_story do
      id("asana.story.create")
      resource(:story)
      verb(:create)
      data_classification(:workspace_content)
      label("Add comment")
      description("Add a comment (story) to an Asana task.")
      handler(Jido.Connect.Asana.Handlers.Actions.CreateStory)

      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:pat, :oauth2], default: :pat)
        policies([:workspace_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:task_gid, :string,
          required?: true,
          description: "Asana task GID to comment on."
        )

        field(:text, :string,
          required?: true,
          description: "Comment text."
        )

        field(:is_pinned, :boolean,
          default: nil,
          description: "Whether to pin the comment."
        )
      end

      output do
        field(:story, :map)
      end
    end
  end
end
