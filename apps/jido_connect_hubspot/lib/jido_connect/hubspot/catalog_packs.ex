defmodule Jido.Connect.HubSpot.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common HubSpot CRM tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:hubspot_reader` | read | contact, company, deal queries |
  | `:hubspot_sales_editor` | write | reader + contact/deal mutations and notes |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @contact_read_tools [
    "hubspot.contacts.contact.get",
    "hubspot.contacts.contact.list",
    "hubspot.contacts.contact.search"
  ]

  @company_read_tools [
    "hubspot.companies.company.get",
    "hubspot.companies.company.list",
    "hubspot.companies.company.search"
  ]

  @deal_read_tools [
    "hubspot.deals.deal.get",
    "hubspot.deals.deal.list",
    "hubspot.deals.deal.search"
  ]

  @reader_tools @contact_read_tools ++
                  @company_read_tools ++
                  @deal_read_tools

  @contact_write_tools [
    "hubspot.contacts.contact.create",
    "hubspot.contacts.contact.update"
  ]

  @deal_write_tools [
    "hubspot.deals.deal.create",
    "hubspot.deals.deal.update"
  ]

  @note_tools [
    "hubspot.notes.note.create"
  ]

  @sales_editor_tools @reader_tools ++
                        @contact_write_tools ++
                        @deal_write_tools ++
                        @note_tools

  @doc "Returns all built-in HubSpot catalog packs."
  def all, do: [reader(), sales_editor()]

  @doc "Read-only HubSpot CRM pack for contact, company, and deal queries."
  def reader do
    Pack.new!(%{
      id: :hubspot_reader,
      label: "HubSpot reader",
      description: "Read HubSpot CRM contacts, companies, and deals without mutation tools.",
      filters: %{provider: :hubspot},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_hubspot, risk: :read}
    })
  end

  @doc "HubSpot sales-editor pack for CRM read, contact/deal mutations, and notes."
  def sales_editor do
    Pack.new!(%{
      id: :hubspot_sales_editor,
      label: "HubSpot sales editor",
      description:
        "Read HubSpot CRM contacts, companies, and deals, plus create and update contacts and deals, and create notes.",
      filters: %{provider: :hubspot},
      allowed_tools: @sales_editor_tools,
      metadata: %{package: :jido_connect_hubspot, risk: :write}
    })
  end
end
