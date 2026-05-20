defmodule Jido.Connect.Asana.Triggers.Tasks do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Asana.ScopeResolver

  triggers do
    webhook :task_changed do
      id("asana.task.changed")
      resource(:task)
      verb(:watch)
      data_classification(:workspace_content)
      label("Task changed")

      description("Receive Asana webhook notifications when a task is updated.")

      verification(%{
        kind: :asana_webhook,
        signature: :hmac_sha256,
        header: "X-Hook-Signature"
      })

      handler(Jido.Connect.Asana.Handlers.Triggers.TaskChangedWebhook)

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
        field(:parent_gid, :string)
        field(:parent_type, :string)
        field(:user_gid, :string)
        field(:user_name, :string)
        field(:occurred_at, :string)
      end
    end

    webhook :task_added do
      id("asana.task.added")
      resource(:task)
      verb(:watch)
      data_classification(:workspace_content)
      label("Task added")

      description("Receive Asana webhook notifications when a task is created.")

      verification(%{
        kind: :asana_webhook,
        signature: :hmac_sha256,
        header: "X-Hook-Signature"
      })

      handler(Jido.Connect.Asana.Handlers.Triggers.TaskAddedWebhook)

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
        field(:parent_gid, :string)
        field(:parent_type, :string)
        field(:user_gid, :string)
        field(:user_name, :string)
        field(:occurred_at, :string)
      end
    end

    webhook :task_deleted do
      id("asana.task.deleted")
      resource(:task)
      verb(:watch)
      data_classification(:workspace_content)
      label("Task deleted")

      description("Receive Asana webhook notifications when a task is deleted.")

      verification(%{
        kind: :asana_webhook,
        signature: :hmac_sha256,
        header: "X-Hook-Signature"
      })

      handler(Jido.Connect.Asana.Handlers.Triggers.TaskDeletedWebhook)

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
        field(:parent_gid, :string)
        field(:parent_type, :string)
        field(:user_gid, :string)
        field(:user_name, :string)
        field(:occurred_at, :string)
      end
    end
  end
end
