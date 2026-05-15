defmodule Jido.Connect.Google.Tasks.Triggers.Tasks do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @scope_resolver Jido.Connect.Google.Tasks.ScopeResolver

  triggers do
    poll :task_changed do
      id("google.tasks.task.changed")
      resource(:task)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Task changed")

      description(
        "Poll Google Tasks for task changes within a task list using updatedMin timestamp checkpoints."
      )

      interval_ms(300_000)
      checkpoint(:updated_min)
      dedupe(%{key: [:task_id, :updated]})
      handler(Jido.Connect.Google.Tasks.Handlers.Triggers.TaskChangedPoller)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:task_list_id, :string,
          required?: true,
          example: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
          description: "Task list ID to poll for changes."
        )

        field(:page_size, :integer,
          default: 100,
          description: "Maximum number of tasks to return per page (1–100)."
        )

        field(:show_deleted, :boolean,
          default: true,
          description: "Include deleted tasks in the result."
        )

        field(:show_completed, :boolean, description: "Include completed tasks in the result.")

        field(:show_hidden, :boolean, description: "Include hidden tasks in the result.")
      end

      signal do
        field(:task_id, :string)
        field(:task_list_id, :string)
        field(:title, :string)
        field(:status, :string)
        field(:change_type, :string)
        field(:due, :string)
        field(:completed, :string)
        field(:updated, :string)
        field(:task, :map)
      end
    end
  end
end
