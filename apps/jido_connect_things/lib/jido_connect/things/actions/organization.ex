defmodule Jido.Connect.Things.Actions.Organization do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @guarded %{
    strict_input?: true,
    unofficial_api?: true,
    prepare_commit_required?: true
  }

  actions do
    action :schedule_todo do
      id("things.todo.schedule")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Schedule Things to-do")
      description("Set one to-do to Inbox, Today, Evening, Anytime, Someday, or an ISO date.")
      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 32)
        field(:expected_modified_at, :string, required?: true, min_length: 1, max_length: 64)
        field(:schedule, :string, required?: true, min_length: 1, max_length: 32)
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end

    action :set_todo_deadline do
      id("things.todo.deadline.set")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Set Things to-do deadline")
      description("Set one to-do deadline to an ISO date.")
      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 32)
        field(:expected_modified_at, :string, required?: true, min_length: 1, max_length: 64)
        field(:deadline, :string, required?: true, min_length: 10, max_length: 10)
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end

    action :clear_todo_deadline do
      id("things.todo.deadline.clear")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Clear Things to-do deadline")
      description("Clear one to-do deadline.")
      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 32)
        field(:expected_modified_at, :string, required?: true, min_length: 1, max_length: 64)
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end

    action :set_todo_tags do
      id("things.todo.tags.set")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Replace Things to-do tags")
      description("Replace all tags on one to-do with validated current tags.")
      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 32)
        field(:expected_modified_at, :string, required?: true, min_length: 1, max_length: 64)
        field(:tag_ids, {:array, :string}, required?: true)
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end

    action :move_todo do
      id("things.todo.move")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Move Things to-do")

      description("Move one to-do to the root, an area, or a project with an optional heading.")

      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 32)
        field(:expected_modified_at, :string, required?: true, min_length: 1, max_length: 64)
        field(:area_id, :string, min_length: 1, max_length: 32)
        field(:project_id, :string, min_length: 1, max_length: 32)
        field(:heading_id, :string, min_length: 1, max_length: 32)
        field(:schedule, :string, min_length: 1, max_length: 32)
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end
  end
end
