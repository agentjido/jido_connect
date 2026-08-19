defmodule Jido.Connect.Trello.Actions.Checklists do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Trello.Contract

  actions do
    action :list_checklists do
      id("trello.checklist.list")
      resource(:checklist)
      verb(:list)
      data_classification(:workspace_content)
      label("List checklists")
      description("List checklists on one card on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      input do
        field(:card_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:cursor, :string, min_length: 1, max_length: Contract.cursor_max())
        field(:limit, :integer, default: 25, minimum: 1, maximum: 100)
      end

      output do
        field(:kind, :string)
        field(:items, {:array, :map})
        field(:pageInfo, :map)
      end
    end

    action :create_checklist do
      id("trello.checklist.create")
      resource(:checklist)
      verb(:create)
      data_classification(:workspace_content)
      label("Create checklist")
      description("Create one checklist on one selected-board card.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ChecklistCreate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:card_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:name, :string, required?: true, min_length: 1, max_length: Contract.name_max())
        field(:position, :any)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:checklist, :map)
      end
    end

    action :update_checklist do
      id("trello.checklist.update")
      resource(:checklist)
      verb(:update)
      data_classification(:workspace_content)
      label("Update checklist")
      description("Update one checklist on one selected-board card.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ChecklistUpdate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:card_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:checklist_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:name, :string, min_length: 1, max_length: Contract.name_max())
        field(:position, :any)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:checklist, :map)
      end
    end

    action :create_checklist_item do
      id("trello.checklist.item.create")
      resource(:checklist_item)
      verb(:create)
      data_classification(:workspace_content)
      label("Create checklist item")
      description("Create one item in a checklist on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ChecklistItemCreate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:card_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:checklist_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:text, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.checklist_text_max()
        )

        field(:position, :any)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:item, :map)
      end
    end

    action :update_checklist_item do
      id("trello.checklist.item.update")
      resource(:checklist_item)
      verb(:update)
      data_classification(:workspace_content)
      label("Update checklist item")
      description("Update one checklist item on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ChecklistItemUpdate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:card_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:checklist_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:item_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:text, :string, min_length: 1, max_length: Contract.checklist_text_max())
        field(:checked, :boolean)
        field(:position, :any)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:item, :map)
      end
    end
  end
end
