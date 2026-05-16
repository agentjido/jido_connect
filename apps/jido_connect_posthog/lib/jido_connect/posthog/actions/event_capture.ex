defmodule Jido.Connect.PostHog.Actions.EventCapture do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.PostHog.ScopeResolver

  actions do
    action :capture_event do
      id("posthog.event.capture")
      resource(:event)
      verb(:create)
      data_classification(:workspace_content)
      label("Capture event")
      description("Capture a single event in PostHog.")
      handler(Jido.Connect.PostHog.Handlers.Actions.CaptureEvent)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["events:write"], resolver: @scope_resolver)
      end

      input do
        field(:event, :string,
          required?: true,
          description: "Event name to capture."
        )

        field(:distinct_id, :string,
          required?: true,
          description: "Distinct ID of the user who triggered the event."
        )

        field(:properties, :map,
          default: %{},
          description: "Event properties."
        )

        field(:timestamp, :string,
          default: nil,
          description: "ISO 8601 timestamp for the event."
        )
      end

      output do
        field(:status, :string)
      end
    end

    action :batch_capture_events do
      id("posthog.event.batch_capture")
      resource(:event)
      verb(:create)
      data_classification(:workspace_content)
      label("Batch capture events")
      description("Capture a batch of events in PostHog.")
      handler(Jido.Connect.PostHog.Handlers.Actions.BatchCaptureEvents)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["events:write"], resolver: @scope_resolver)
      end

      input do
        field(:events, {:array, :map},
          required?: true,
          description: "List of events to capture. Each must contain event and distinct_id."
        )
      end

      output do
        field(:status, :string)
        field(:count, :integer)
      end
    end
  end
end
