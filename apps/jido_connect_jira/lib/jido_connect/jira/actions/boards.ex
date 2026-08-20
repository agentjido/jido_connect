defmodule Jido.Connect.Jira.Actions.Boards do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver
  @max_id 2_147_483_647

  actions do
    action :list_boards do
      id("jira.board.list")
      resource(:board)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List boards")
      description("List Jira Software boards visible to the authenticated user.")
      handler(Jido.Connect.Jira.Handlers.Actions.ListBoards)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, min_length: 1, max_length: 254)
        field(:project, :string, min_length: 1, max_length: 255)
        field(:type, :string, enum: ["scrum", "kanban", "simple"])
        field(:limit, :integer, default: 50, minimum: 1, maximum: 100)
        field(:offset, :integer, default: 0, minimum: 0, maximum: @max_id)
      end

      output do
        field(:boards, {:array, :map})
        field(:total, :integer)
        field(:offset, :integer)
        field(:limit, :integer)
        field(:is_last, :boolean)
      end
    end

    action :get_board do
      id("jira.board.get")
      resource(:board)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get board")
      description("Get one Jira Software board by ID.")
      handler(Jido.Connect.Jira.Handlers.Actions.GetBoard)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:id, :integer, required?: true, minimum: 1, maximum: @max_id)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:type, :string)
        field(:location, :map)
        field(:url, :string)
      end
    end

    action :create_board do
      id("jira.board.create")
      resource(:board)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create board")
      description("Create a Jira Software board from one saved filter.")
      handler(Jido.Connect.Jira.Handlers.Actions.CreateBoard)
      preview(Jido.Connect.Jira.Previews.CreateBoard)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true, min_length: 1, max_length: 254)
        field(:type, :string, required?: true, enum: ["scrum", "kanban"])
        field(:filter_id, :integer, required?: true, minimum: 1, maximum: @max_id)
        field(:location, :string, default: "user", enum: ["user", "project"])
        field(:project, :string, min_length: 1, max_length: 255)
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:type, :string)
        field(:location, :map)
        field(:url, :string)
      end
    end
  end
end
