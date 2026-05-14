defmodule Jido.Connect.Gmail.Actions.Watch do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @scope_resolver Jido.Connect.Gmail.ScopeResolver

  actions do
    action :start_watch do
      id("google.gmail.watch.start")
      resource(:mailbox_watch)
      verb(:watch)
      data_classification(:personal_data)
      label("Start Gmail watch")
      description("Start or renew Gmail push notifications for the authenticated mailbox.")
      handler(Jido.Connect.Gmail.Handlers.Actions.StartWatch)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:topic_name, :string, required?: true, example: "projects/my-project/topics/gmail")
        field(:label_ids, {:array, :string}, default: [])
        field(:label_filter_behavior, :string, enum: ["include", "exclude"])
      end

      output do
        field(:watch, :map)
      end
    end

    action :stop_watch do
      id("google.gmail.watch.stop")
      resource(:mailbox_watch)
      verb(:delete)
      data_classification(:personal_data)
      label("Stop Gmail watch")
      description("Stop Gmail push notification delivery for the authenticated mailbox.")
      handler(Jido.Connect.Gmail.Handlers.Actions.StopWatch)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:result, :map)
      end
    end
  end
end
