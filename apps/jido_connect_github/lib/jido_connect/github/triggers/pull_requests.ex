defmodule Jido.Connect.GitHub.Triggers.PullRequests do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
    webhook :pull_request_webhook do
      id "github.webhook.pull_request"
      resource :pull_request
      verb :watch
      data_classification :workspace_metadata
      label "Pull request webhook"
      description "Receive verified GitHub pull request events."

      verification %{kind: :github_signed_request, signature_header: "x-hub-signature-256"}
      dedupe %{key: [:delivery_id]}
      handler Jido.Connect.GitHub.Handlers.Triggers.PullRequestWebhook

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      signal do
        field :repo, :string, required?: true
        field :pull_number, :integer, required?: true
        field :action, :string, required?: true
        field :delivery_id, :string, required?: true
      end
    end
  end
end
