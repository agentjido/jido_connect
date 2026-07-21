defmodule Jido.Connect.Google.Tasks.Actions.TaskLists do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @write_scope "https://www.googleapis.com/auth/tasks"
  @scope_resolver Jido.Connect.Google.Tasks.ScopeResolver

  actions do
    action :list_task_lists do
      id("google.tasks.tasklist.list")
      resource(:task_list)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List task lists")
      description("List all authenticated user's Google Tasks task lists.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.ListTaskLists)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer,
          example: 20,
          description: "Maximum number of task lists to return per page (1–100)."
        )

        field(:page_token, :string,
          example: "CAESNQIIARICIAAoAA",
          description: "Token for the next page of results."
        )
      end

      output do
        field(:task_lists, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_task_list do
      id("google.tasks.tasklist.get")
      resource(:task_list)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get task list")
      description("Fetch a single Google Tasks task list by ID.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.GetTaskList)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx"
        )

        field(:fields, :string, description: "Fields to include in a partial response.")
      end

      output do
        field(:task_list, :map)
      end
    end

    action :create_task_list do
      id("google.tasks.tasklist.create")
      resource(:task_list)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create task list")
      description("Create a new Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.CreateTaskList)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:title, :string, required?: true, example: "Work Tasks")
      end

      output do
        field(:task_list, :map)
      end
    end

    action :update_task_list do
      id("google.tasks.tasklist.update")
      resource(:task_list)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update task list")
      description("Update the title of an existing Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.UpdateTaskList)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx"
        )

        field(:title, :string, required?: true, example: "Updated Tasks")
      end

      output do
        field(:task_list, :map)
      end
    end

    action :delete_task_list do
      id("google.tasks.tasklist.delete")
      resource(:task_list)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete task list")
      description("Delete an authenticated user's Google Tasks task list.")
      handler(Jido.Connect.Google.Tasks.Handlers.Actions.DeleteTaskList)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx"
        )
      end

      output do
        field(:result, :map)
      end
    end
  end
end
