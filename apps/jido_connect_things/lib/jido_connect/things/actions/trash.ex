defmodule Jido.Connect.Things.Actions.Trash do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @guarded %{
    strict_input?: true,
    unofficial_api?: true,
    prepare_commit_required?: true
  }

  actions do
    action :trash_todo do
      id("things.todo.trash")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Move Things to-do to Trash")
      description("Move one current non-recurring Things to-do to Trash without deleting it.")
      handler(Jido.Connect.Things.Handlers.Actions.CommitTodo)
      effect(:destructive, confirmation: :always)
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

    action :restore_todo do
      id("things.todo.restore")
      resource(:todo)
      verb(:update)
      data_classification(:personal_data)
      label("Restore Things to-do")
      description("Restore one current non-recurring Things to-do from Trash.")
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
