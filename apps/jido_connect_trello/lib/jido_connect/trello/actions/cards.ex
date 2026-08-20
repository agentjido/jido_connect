defmodule Jido.Connect.Trello.Actions.Cards do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Trello.Contract

  actions do
    action :list_cards do
      id("trello.card.list")
      resource(:card)
      verb(:list)
      data_classification(:workspace_content)
      label("List cards")
      description("List cards on the selected board or in one selected-board list.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      input do
        field(:list_id, :string, min_length: 1, max_length: Contract.ari_max())
        field(:state, :string, enum: ["open", "archived", "all"], default: "open")
        field(:cursor, :string, min_length: 1, max_length: Contract.cursor_max())
        field(:limit, :integer, default: 25, minimum: 1, maximum: 50)
      end

      output do
        field(:kind, :string)
        field(:items, {:array, :map})
        field(:pageInfo, :map)
      end
    end

    action :get_card do
      id("trello.card.get")
      resource(:card)
      verb(:get)
      data_classification(:workspace_content)
      label("Get card")
      description("Get one card from the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: 2_048)
      end

      output do
        field(:kind, :string)
        field(:card, :map)
      end
    end

    action :search_cards do
      id("trello.card.search")
      resource(:card)
      verb(:search)
      data_classification(:workspace_content)
      label("Search cards")
      description("Search for cards only on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read", "trello:search"])
      end

      input do
        field(:query, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.query_max()
        )

        field(:cursor, :string, min_length: 1, max_length: Contract.cursor_max())
        field(:limit, :integer, default: 10, minimum: 1, maximum: 100)
        field(:partial, :boolean, default: false)
      end

      output do
        field(:kind, :string)
        field(:items, {:array, :map})
        field(:pageInfo, :map)
      end
    end

    action :create_card do
      id("trello.card.create")
      resource(:card)
      verb(:create)
      data_classification(:workspace_content)
      label("Create card")
      description("Create one card in a list on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardCreate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:list_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:name, :string, required?: true, min_length: 1, max_length: Contract.name_max())
        field(:description, :string, min_length: 0, max_length: Contract.description_max())
        field(:due, :string, min_length: 1, max_length: 64)
        field(:position, :any, json_schema: Contract.position_schema())
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end

    action :update_card do
      id("trello.card.update")
      resource(:card)
      verb(:update)
      data_classification(:workspace_content)
      label("Update card")
      description("Update one card name, description, or due date.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardUpdate)
      effect(:write, confirmation: :required_for_ai)
      input_json_schema_overlay(Jido.Connect.Schema.at_least_one_of([:name, :description, :due]))

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

        field(:name, :string, min_length: 1, max_length: Contract.name_max())
        field(:description, :string, min_length: 0, max_length: Contract.description_max())
        field(:due, :string, min_length: 1, max_length: 64)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end

    action :move_card do
      id("trello.card.move")
      resource(:card)
      verb(:update)
      data_classification(:workspace_content)
      label("Move card")
      description("Move one card to another list on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardMove)
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

        field(:list_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )

        field(:position, :any, json_schema: Contract.position_schema())
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end

    action :complete_card do
      id("trello.card.complete")
      resource(:card)
      verb(:update)
      data_classification(:workspace_content)
      label("Complete card")
      description("Mark one card on the selected Trello board as complete.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardComplete)
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
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end

    action :archive_card do
      id("trello.card.archive")
      resource(:card)
      verb(:archive)
      data_classification(:workspace_content)
      label("Archive card")
      description("Archive one card on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardArchive)
      effect(:destructive, confirmation: :always)

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
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end

    action :attach_card_label do
      id("trello.card.label.attach")
      resource(:card_label)
      verb(:update)
      data_classification(:workspace_content)
      label("Attach label")
      description("Attach one existing board label to one board card.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardLabelAttach)
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

        field(:label_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end

    action :detach_card_label do
      id("trello.card.label.detach")
      resource(:card_label)
      verb(:update)
      data_classification(:workspace_content)
      label("Detach label")
      description("Detach one existing board label from one board card.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.CardLabelDetach)
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

        field(:label_id, :string,
          required?: true,
          min_length: 1,
          max_length: Contract.ari_max()
        )
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:card, :map)
      end
    end
  end
end
