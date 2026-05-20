defmodule Jido.Connect.Asana.Triggers.Projects do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Asana.ScopeResolver

  triggers do
    webhook :project_changed do
      id("asana.project.changed")
      resource(:project)
      verb(:watch)
      data_classification(:workspace_content)
      label("Project changed")

      description("Receive Asana webhook notifications when a project is updated.")

      verification(%{
        kind: :asana_webhook,
        signature: :hmac_sha256,
        header: "X-Hook-Signature"
      })

      handler(Jido.Connect.Asana.Handlers.Triggers.ProjectChangedWebhook)

      access do
        auth([:pat, :oauth2], default: :pat)
        scopes(["default", "read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Asana webhook shared secret for signature verification."
        )
      end

      signal do
        field(:resource_gid, :string)
        field(:resource_type, :string)
        field(:resource_name, :string)
        field(:action, :string)
        field(:change_type, :string)
        field(:user_gid, :string)
        field(:user_name, :string)
        field(:occurred_at, :string)
      end
    end
  end
end
