defmodule Jido.Connect.Linear.Actions.Teams do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Linear.ScopeResolver

  actions do
    action :list_teams do
      id("linear.team.list")
      resource(:team)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List teams")
      description("List Linear teams visible to the authenticated user.")
      handler(Jido.Connect.Linear.Handlers.Actions.ListTeams)
      effect(:read)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        scopes(["read"], resolver: @scope_resolver)
      end

      input do
        field(:first, :integer, default: 50)
        field(:after, :string, default: nil)
      end

      output do
        field(:teams, {:array, :map})
        field(:has_next_page, :boolean)
        field(:end_cursor, :string)
      end
    end

    action :get_team do
      id("linear.team.get")
      resource(:team)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get team")
      description("Fetch a Linear team by ID.")
      handler(Jido.Connect.Linear.Handlers.Actions.GetTeam)
      effect(:read)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        scopes(["read"], resolver: @scope_resolver)
      end

      input do
        field(:team_id, :string, required?: true, example: "team-1")
      end

      output do
        field(:id, :string)
        field(:key, :string)
        field(:name, :string)
        field(:description, :string)
        field(:icon, :string)
        field(:color, :string)
        field(:lead, :map)
      end
    end
  end
end
