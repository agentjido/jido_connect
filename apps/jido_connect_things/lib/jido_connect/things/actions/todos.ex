defmodule Jido.Connect.Things.Actions.Todos do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @strict %{strict_input?: true, unofficial_api?: true}
  @guarded Map.put(@strict, :prepare_commit_required?, true)

  actions do
    action :list_inbox_todos do
      id("things.todo.list")
      resource(:todo)
      verb(:list)
      data_classification(:personal_data)
      label("List open Inbox to-dos")
      description("List open to-dos in the selected Things Cloud Inbox.")
      handler(Jido.Connect.Things.Handlers.Actions.ListTodos)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:view, :string,
          default: "inbox",
          enum: ["inbox"],
          description: "Task view. The first provider slice supports Inbox only."
        )

        field(:limit, :integer,
          default: 25,
          minimum: 1,
          maximum: 100,
          description: "Maximum number of open Inbox to-dos to return."
        )
      end

      output do
        field(:view, :string, required?: true)
        field(:count, :integer, required?: true)
        field(:todos, {:array, :map}, required?: true)
        field(:freshness, :map)
      end
    end

    action :create_inbox_todo do
      id("things.todo.create")
      resource(:todo)
      verb(:create)
      data_classification(:personal_data)
      label("Create Inbox to-do")
      description("Create one open to-do in the selected Things Cloud Inbox.")
      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:title, :string,
          required?: true,
          min_length: 1,
          max_length: 2_000,
          description: "To-do title."
        )

        field(:notes, :string,
          max_length: 100_000,
          description: "Optional to-do notes."
        )
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end

    action :update_inbox_todo do
      id("things.todo.update")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Update Inbox to-do")

      description(
        "Change the title or notes of one open to-do in the selected Things Cloud Inbox."
      )

      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:external_write, confirmation: :required_for_ai)
      metadata(@guarded)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string,
          required?: true,
          min_length: 1,
          max_length: 32,
          description: "Stable Things object ID."
        )

        field(:expected_modified_at, :string,
          required?: true,
          min_length: 1,
          max_length: 64,
          metadata: %{format: :date_time},
          description: "Exact modification time from the current provider record."
        )

        field(:title, :string,
          min_length: 1,
          max_length: 2_000,
          description: "Replacement title."
        )

        field(:notes, :string,
          max_length: 100_000,
          description: "Replacement notes."
        )
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end
  end
end
