defmodule Jido.Connect.Google.Forms.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Forms tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.forms.form.get",
    "google.forms.responses.list",
    "google.forms.responses.get",
    "google.forms.response.submitted"
  ]

  @responder_tools [
    "google.forms.form.get",
    "google.forms.responses.list",
    "google.forms.responses.get",
    "google.forms.response.submitted",
    "google.forms.watch.create",
    "google.forms.watch.renew",
    "google.forms.watch.delete"
  ]

  @editor_tools @readonly_tools ++
                  [
                    "google.forms.form.create",
                    "google.forms.form.batch_update",
                    "google.forms.watch.create",
                    "google.forms.watch.renew",
                    "google.forms.watch.delete"
                  ]

  @doc "Returns all built-in Google Forms catalog packs."
  def all, do: [readonly(), responder(), editor()]

  @doc "Read-only Forms metadata and content pack."
  def readonly do
    Pack.new!(%{
      id: :google_forms_readonly,
      label: "Google Forms read-only",
      description:
        "Read Google Forms form metadata, content, and response-submitted webhook events without mutation tools.",
      filters: %{provider: :google_forms},
      allowed_tools: @readonly_tools,
      metadata: %{package: :jido_connect_google_forms, risk: :read}
    })
  end

  @doc "Responder pack for reading form content, listing responses, and managing watches."
  def responder do
    Pack.new!(%{
      id: :google_forms_responder,
      label: "Google Forms responder",
      description:
        "Read form content, list and retrieve responses, and manage response watches. Excludes form creation and mutation tools.",
      filters: %{provider: :google_forms},
      allowed_tools: @responder_tools,
      metadata: %{package: :jido_connect_google_forms, risk: :write}
    })
  end

  @doc "Forms editor pack for form creation, mutation, and response management."
  def editor do
    Pack.new!(%{
      id: :google_forms_editor,
      label: "Google Forms editor",
      description:
        "Read, create, and update Google Forms. Includes all mutation and response tools.",
      filters: %{provider: :google_forms},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_google_forms, risk: :write}
    })
  end
end
