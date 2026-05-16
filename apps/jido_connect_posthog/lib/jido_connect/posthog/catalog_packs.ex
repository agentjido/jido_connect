defmodule Jido.Connect.PostHog.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common PostHog tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:posthog_reader` | read | event, person, and insight queries |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @event_read_tools [
    "posthog.event.list",
    "posthog.event.get"
  ]

  @person_read_tools [
    "posthog.person.list",
    "posthog.person.get"
  ]

  @insight_read_tools [
    "posthog.insight.list",
    "posthog.insight.get"
  ]

  @reader_tools @event_read_tools ++ @person_read_tools ++ @insight_read_tools

  @doc "Returns all built-in PostHog catalog packs."
  def all, do: [reader()]

  @doc "Read-only PostHog pack for event, person, and insight queries."
  def reader do
    Pack.new!(%{
      id: :posthog_reader,
      label: "PostHog reader",
      description: "Read PostHog events, persons, and insights.",
      filters: %{provider: :posthog},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_posthog, risk: :read}
    })
  end
end
