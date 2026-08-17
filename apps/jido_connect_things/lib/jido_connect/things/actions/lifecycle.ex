defmodule Jido.Connect.Things.Actions.Lifecycle do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @guarded %{
    strict_input?: true,
    unofficial_api?: true,
    prepare_commit_required?: true
  }

  actions do
    action :complete_todo do
      id("things.todo.complete")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Complete Things to-do")
      description("Complete one current non-recurring Things to-do.")
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

    action :cancel_todo do
      id("things.todo.cancel")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Cancel Things to-do")
      description("Cancel one current non-recurring Things to-do.")
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

    action :reopen_todo do
      id("things.todo.reopen")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Reopen Things to-do")
      description("Reopen one completed or canceled non-recurring Things to-do.")
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
  end
end
