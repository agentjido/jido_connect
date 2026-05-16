defmodule Jido.Connect.PostHog.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common PostHog tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:posthog_reader` | read | event, person, insight, and feature flag queries |
  | `:posthog_writer` | write | event capture operations |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @event_read_tools [
    "posthog.event.list",
    "posthog.event.get"
  ]

  @event_write_tools [
    "posthog.event.capture",
    "posthog.event.batch_capture"
  ]

  @person_read_tools [
    "posthog.person.list",
    "posthog.person.get"
  ]

  @insight_read_tools [
    "posthog.insight.list",
    "posthog.insight.get"
  ]

  @feature_flag_read_tools [
    "posthog.feature_flag.evaluate",
    "posthog.feature_flag.list",
    "posthog.feature_flag.get"
  ]

  @reader_tools @event_read_tools ++
                  @person_read_tools ++ @insight_read_tools ++ @feature_flag_read_tools

  @doc "Returns all built-in PostHog catalog packs."
  def all, do: [reader(), writer()]

  @doc "Read-only PostHog pack for event, person, insight, and feature flag queries."
  def reader do
    Pack.new!(%{
      id: :posthog_reader,
      label: "PostHog reader",
      description: "Read PostHog events, persons, insights, and feature flags.",
      filters: %{provider: :posthog},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_posthog, risk: :read}
    })
  end

  @doc "Write pack for PostHog event capture operations."
  def writer do
    Pack.new!(%{
      id: :posthog_writer,
      label: "PostHog writer",
      description: "Capture PostHog events.",
      filters: %{provider: :posthog},
      allowed_tools: @event_write_tools,
      metadata: %{package: :jido_connect_posthog, risk: :write}
    })
  end
end
