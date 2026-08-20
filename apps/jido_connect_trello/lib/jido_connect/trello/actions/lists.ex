defmodule Jido.Connect.Trello.Actions.Lists do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Trello.Contract

  actions do
    action :list_lists do
      id("trello.list.list")
      resource(:list)
      verb(:list)
      data_classification(:workspace_content)
      label("List lists")
      description("List open lists on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      input do
        field(:cursor, :string, min_length: 1, max_length: Contract.cursor_max())
        field(:limit, :integer, default: 25, minimum: 1, maximum: 50)
      end

      output do
        field(:kind, :string)
        field(:items, {:array, :map})
        field(:pageInfo, :map)
      end
    end

    action :get_list do
      id("trello.list.get")
      resource(:list)
      verb(:get)
      data_classification(:workspace_content)
      label("Get list")
      description("Get one list on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      effect(:read)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:read"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: Contract.ari_max())
      end

      output do
        field(:kind, :string)
        field(:list, :map)
      end
    end

    action :create_list do
      id("trello.list.create")
      resource(:list)
      verb(:create)
      data_classification(:workspace_content)
      label("Create list")
      description("Create one list on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ListCreate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:name, :string, required?: true, min_length: 1, max_length: Contract.name_max())
        field(:position, :any, json_schema: Contract.position_schema())
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:list, :map)
      end
    end

    action :update_list do
      id("trello.list.update")
      resource(:list)
      verb(:update)
      data_classification(:workspace_content)
      label("Update list")
      description("Change one list name on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ListUpdate)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: Contract.ari_max())
        field(:name, :string, required?: true, min_length: 1, max_length: Contract.name_max())
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:list, :map)
      end
    end

    action :move_list do
      id("trello.list.move")
      resource(:list)
      verb(:update)
      data_classification(:workspace_content)
      label("Move list")
      description("Move one list on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ListMove)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: Contract.ari_max())

        field(:position, :any,
          required?: true,
          json_schema: Contract.position_schema()
        )
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:list, :map)
      end
    end

    action :archive_list do
      id("trello.list.archive")
      resource(:list)
      verb(:archive)
      data_classification(:workspace_content)
      label("Archive list")
      description("Archive one list on the selected Trello board.")
      handler(Jido.Connect.Trello.Handlers.Action)
      preview(Jido.Connect.Trello.Previews.ListArchive)
      effect(:destructive, confirmation: :always)

      access do
        auth([:oauth_user], default: :oauth_user)
        scopes(["trello:write"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: Contract.ari_max())
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:list, :map)
      end
    end
  end
end
