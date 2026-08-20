defmodule Jido.Connect.Trello.Actions.Boards do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Trello.Contract

  actions do
    action :get_board do
      id("trello.board.get")
      resource(:board)
      verb(:get)
      data_classification(:workspace_content)
      label("Get board")
      description("Get the board fixed by the selected Trello connection.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      output do
        field(:kind, :string)
        field(:board, :map)
      end
    end

    action :list_labels do
      id("trello.label.list")
      resource(:label)
      verb(:list)
      data_classification(:workspace_content)
      label("List labels")
      description("List labels on the board fixed by the selected Trello connection.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      input do
        field(:cursor, :string, min_length: 1, max_length: Contract.cursor_max())
        field(:limit, :integer, default: 25, minimum: 1, maximum: 100)
      end

      output do
        field(:kind, :string)
        field(:items, {:array, :map})
        field(:pageInfo, :map)
      end
    end
  end
end
