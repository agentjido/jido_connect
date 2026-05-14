defmodule Jido.Connect.Google.Meet.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Meet tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @future_triggers [
    "google.meet.conference.started",
    "google.meet.conference.ended",
    "google.meet.participant.joined",
    "google.meet.participant.left",
    "google.meet.recording.started",
    "google.meet.recording.ended",
    "google.meet.recording.file_generated",
    "google.meet.transcript.started",
    "google.meet.transcript.ended",
    "google.meet.transcript.file_generated"
  ]

  @reader_tools [
    "google.meet.space.get",
    "google.meet.conference_record.list",
    "google.meet.conference_record.get",
    "google.meet.recording.list",
    "google.meet.recording.get",
    "google.meet.transcript.list",
    "google.meet.transcript.get"
  ]

  @scheduler_tools @reader_tools ++
                     [
                       "google.meet.space.create"
                     ]

  @doc "Returns all built-in Google Meet catalog packs."
  def all, do: [reader(), scheduler()]

  @doc "Read-only Meet metadata pack for spaces, conferences, recordings, and transcripts."
  def reader do
    Pack.new!(%{
      id: :google_meet_reader,
      label: "Google Meet reader",
      description:
        "Read Meet space, conference record, recording, and transcript metadata without mutation tools.",
      filters: %{provider: :google_meet},
      allowed_tools: @reader_tools,
      metadata: metadata(:read)
    })
  end

  @doc "Meet scheduling pack with metadata reads and meeting-space creation."
  def scheduler do
    Pack.new!(%{
      id: :google_meet_scheduler,
      label: "Google Meet scheduler",
      description: "Read Meet metadata and create meeting spaces. Triggers remain later work.",
      filters: %{provider: :google_meet},
      allowed_tools: @scheduler_tools,
      metadata: metadata(:write)
    })
  end

  defp metadata(risk) do
    %{
      package: :jido_connect_google_meet,
      risk: risk,
      triggers: :later,
      future_triggers: @future_triggers
    }
  end
end
