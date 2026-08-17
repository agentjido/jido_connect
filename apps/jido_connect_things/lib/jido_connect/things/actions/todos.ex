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
      label("List Things to-dos")
      description("List current Things to-dos with V1 section and relation filters.")
      handler(Jido.Connect.Things.Handlers.Actions.ListTodos)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:view, :string,
          default: "inbox",
          enum: [
            "all",
            "inbox",
            "today",
            "evening",
            "anytime",
            "someday",
            "upcoming",
            "logbook",
            "trash"
          ],
          description: "Things section to list."
        )

        field(:status, :string,
          default: "all",
          enum: ["all", "open", "completed", "canceled"],
          description: "Optional status filter."
        )

        field(:query, :string,
          min_length: 1,
          max_length: 500,
          description: "Case-insensitive title or note text."
        )

        field(:area_id, :string, min_length: 1, max_length: 32)
        field(:project_id, :string, min_length: 1, max_length: 32)
        field(:heading_id, :string, min_length: 1, max_length: 32)
        field(:tag_ids, {:array, :string}, default: [])
        field(:deadline_from, :string, metadata: %{format: :date})
        field(:deadline_to, :string, metadata: %{format: :date})
        field(:scheduled_from, :string, metadata: %{format: :date})
        field(:scheduled_to, :string, metadata: %{format: :date})

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

    action :get_todo do
      id("things.todo.get")
      resource(:todo)
      verb(:get)
      data_classification(:personal_data)
      label("Get Things task")
      description("Get one current task or project by exact ID or unique ID prefix.")
      handler(Jido.Connect.Things.Handlers.Actions.GetTodo)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 32)
      end

      output do
        field(:todo, :map, required?: true)
        field(:freshness, :map, required?: true)
      end
    end

    action :search_todos do
      id("things.todo.search")
      resource(:todo)
      verb(:search)
      data_classification(:personal_data)
      label("Search Things to-dos")
      description("Search current Things to-dos by title or note text.")
      handler(Jido.Connect.Things.Handlers.Actions.SearchTodos)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      input do
        field(:query, :string, required?: true, min_length: 1, max_length: 500)

        field(:view, :string,
          default: "all",
          enum: [
            "all",
            "inbox",
            "today",
            "evening",
            "anytime",
            "someday",
            "upcoming",
            "logbook",
            "trash"
          ]
        )

        field(:status, :string,
          default: "all",
          enum: ["all", "open", "completed", "canceled"]
        )

        field(:area_id, :string, min_length: 1, max_length: 32)
        field(:project_id, :string, min_length: 1, max_length: 32)
        field(:heading_id, :string, min_length: 1, max_length: 32)
        field(:tag_ids, {:array, :string}, default: [])
        field(:deadline_from, :string, metadata: %{format: :date})
        field(:deadline_to, :string, metadata: %{format: :date})
        field(:scheduled_from, :string, metadata: %{format: :date})
        field(:scheduled_to, :string, metadata: %{format: :date})
        field(:limit, :integer, default: 25, minimum: 1, maximum: 100)
      end

      output do
        field(:view, :string, required?: true)
        field(:count, :integer, required?: true)
        field(:todos, {:array, :map}, required?: true)
        field(:freshness, :map, required?: true)
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
          max_length: 10_000,
          description: "Optional to-do notes."
        )

        field(:schedule, :string,
          min_length: 1,
          max_length: 32,
          description: "Inbox, Today, Evening, Anytime, Someday, or an ISO date."
        )

        field(:deadline, :string, min_length: 10, max_length: 10)
        field(:tag_ids, {:array, :string}, default: [])
        field(:area_id, :string, min_length: 1, max_length: 32)
        field(:project_id, :string, min_length: 1, max_length: 32)
        field(:heading_id, :string, min_length: 1, max_length: 32)
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
          max_length: 10_000,
          description: "Replacement notes."
        )
      end

      output do
        field(:receipt, :map, required?: true)
      end
    end
  end
end
