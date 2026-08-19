defmodule Jido.Connect.Slack.Actions.Identity do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :auth_test do
      id "slack.auth.test"
      resource :auth
      verb :read
      data_classification :identity
      label "Test auth"
      description "Validate a Slack token and return its team, enterprise, user, and bot context."
      handler Jido.Connect.Slack.Handlers.Actions.AuthTest
      effect :read

      access do
        auth [:bot, :user], default: :bot
        policies [:workspace_access]
      end

      output do
        field :team_id, :string
        field :team, :string
        field :url, :string
        field :user_id, :string
        field :user, :string
        field :bot_id, :string
        field :enterprise_id, :string
        field :is_enterprise_install, :boolean
      end
    end

    action :team_info do
      id "slack.team.info"
      resource :team
      verb :read
      data_classification :identity
      label "Get team info"
      description "Return Slack team identity and enterprise metadata for the connection."
      handler Jido.Connect.Slack.Handlers.Actions.TeamInfo
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["team:read"]
      end

      input do
        field :team_id, :string
      end

      output do
        field :team_id, :string
        field :name, :string
        field :domain, :string
        field :email_domain, :string
        field :enterprise_id, :string
        field :enterprise_name, :string
        field :team, :map
      end
    end
  end
end
