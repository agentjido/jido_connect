defmodule Jido.Connect.Google.Sheets.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Sheets tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.sheets.spreadsheet.get",
    "google.sheets.values.get",
    "google.sheets.values.batch_get"
  ]

  @writer_tools @readonly_tools ++
                  [
                    "google.sheets.spreadsheet.create",
                    "google.sheets.values.update",
                    "google.sheets.values.append",
                    "google.sheets.values.clear",
                    "google.sheets.values.batch_update",
                    "google.sheets.values.batch_clear",
                    "google.sheets.sheet.add",
                    "google.sheets.sheet.delete",
                    "google.sheets.sheet.rename"
                  ]

  @doc "Returns all built-in Google Sheets catalog packs."
  def all, do: [readonly(), writer()]

  @doc "Read-only spreadsheet metadata and values pack."
  def readonly do
    Pack.new!(%{
      id: :google_sheets_readonly,
      label: "Google Sheets read-only",
      description: "Read spreadsheet metadata and cell values without mutation tools.",
      filters: %{provider: :google_sheets},
      allowed_tools: @readonly_tools,
      metadata: %{package: :jido_connect_google_sheets, risk: :read}
    })
  end

  @doc "Common Google Sheets writer pack, excluding raw batchUpdate."
  def writer do
    Pack.new!(%{
      id: :google_sheets_writer,
      label: "Google Sheets writer",
      description: "Read and safely mutate Sheets values and tabs. Excludes raw batchUpdate.",
      filters: %{provider: :google_sheets},
      allowed_tools: @writer_tools,
      metadata: %{package: :jido_connect_google_sheets, excludes: ["google.sheets.batch_update"]}
    })
  end
end
