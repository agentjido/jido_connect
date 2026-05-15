defmodule Jido.Connect.Google.Tasks.Actions.Tasks do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @write_scope "https://www.googleapis.com/auth/tasks"
  @scope_resolver Jido.Connect.Google.Tasks.ScopeResolver

  actions do
    action :list_tasks do
      id("google.tasks.task.list")
      resource(:task)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List tasks")
      description("List tasks in a specified Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.ListTasks)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID to list tasks from."
        )

        field(:page_size, :integer,
          example: 20,
          description: "Maximum number of tasks to return per page (1–100)."
        )

        field(:page_token, :string,
          example: "CAESNQIIARICIAAoAA",
          description: "Token for the next page of results."
        )

        field(:show_completed, :boolean, description: "Include completed tasks in the result.")

        field(:show_deleted, :boolean, description: "Include deleted tasks in the result.")

        field(:show_hidden, :boolean, description: "Include hidden tasks in the result.")

        field(:completed_min, :string,
          description: "Lower bound for a task's completion date (RFC 3339 timestamp)."
        )

        field(:completed_max, :string,
          description: "Upper bound for a task's completion date (RFC 3339 timestamp)."
        )

        field(:due_min, :string,
          description: "Lower bound for a task's due date (RFC 3339 timestamp)."
        )

        field(:due_max, :string,
          description: "Upper bound for a task's due date (RFC 3339 timestamp)."
        )

        field(:updated_min, :string,
          description: "Lower bound for a task's last modification time (RFC 3339 timestamp)."
        )
      end

      output do
        field(:tasks, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_task do
      id("google.tasks.task.get")
      resource(:task)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get task")
      description("Fetch a single Google Tasks task by ID.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.GetTask)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID that contains the task."
        )

        field(:task_id, :string,
          required?: true,
          example: "dGFrazEyMzQ1Njc4OQ",
          description: "Task ID to retrieve."
        )

        field(:fields, :string, description: "Fields to include in a partial response.")
      end

      output do
        field(:task, :map)
      end
    end

    action :create_task do
      id("google.tasks.task.create")
      resource(:task)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create task")
      description("Create a new task in a specified Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.CreateTask)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID to create the task in."
        )

        field(:title, :string,
          required?: true,
          example: "Buy groceries",
          description: "Title of the task."
        )

        field(:notes, :string, description: "Notes describing the task.")

        field(:due, :string, description: "Due date of the task (RFC 3339 timestamp).")

        field(:status, :string, description: "Status of the task (needsAction or completed).")

        field(:parent, :string, description: "Parent task ID for nested tasks.")

        field(:position, :string,
          description: "Position among sibling tasks under the same parent."
        )
      end

      output do
        field(:task, :map)
      end
    end

    action :update_task do
      id("google.tasks.task.update")
      resource(:task)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update task")
      description("Update an existing Google Tasks task.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.UpdateTask)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID that contains the task."
        )

        field(:task_id, :string,
          required?: true,
          example: "dGFrazEyMzQ1Njc4OQ",
          description: "Task ID to update."
        )

        field(:title, :string, description: "New title of the task.")

        field(:notes, :string, description: "New notes for the task.")

        field(:status, :string, description: "New status of the task (needsAction or completed).")

        field(:due, :string, description: "New due date of the task (RFC 3339 timestamp).")

        field(:completed, :string,
          description: "Completion date of the task (RFC 3339 timestamp)."
        )

        field(:parent, :string, description: "New parent task ID.")

        field(:position, :string, description: "New position among sibling tasks.")
      end

      output do
        field(:task, :map)
      end
    end

    action :delete_task do
      id("google.tasks.task.delete")
      resource(:task)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete task")
      description("Delete a task from a specified Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.DeleteTask)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID that contains the task."
        )

        field(:task_id, :string,
          required?: true,
          example: "dGFrazEyMzQ1Njc4OQ",
          description: "Task ID to delete."
        )
      end

      output do
        field(:result, :map)
      end
    end

    action :clear_tasks do
      id("google.tasks.task.clear")
      resource(:task)
      verb(:clear)
      data_classification(:workspace_metadata)
      label("Clear completed tasks")
      description("Clear all completed tasks from a specified Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.ClearTasks)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID to clear completed tasks from."
        )
      end

      output do
        field(:result, :map)
      end
    end

    action :move_task do
      id("google.tasks.task.move")
      resource(:task)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Move task")
      description("Move a task to another position or parent within or across task lists.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.MoveTask)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Current task list ID of the task."
        )

        field(:task_id, :string,
          required?: true,
          example: "dGFrazEyMzQ1Njc4OQ",
          description: "Task ID to move."
        )

        field(:destination_parent, :string, description: "New parent task ID.")

        field(:destination_position, :string, description: "New position among sibling tasks.")

        field(:destination_task_list_id, :string,
          description: "Destination task list ID for cross-list moves."
        )
      end

      output do
        field(:task, :map)
      end
    end
  end
end
