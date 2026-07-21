defmodule Jido.Connect.Salesforce.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Salesforce CRM tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:salesforce_reader` | read | contact queries + generic SObject reads |
  | `:salesforce_editor` | write | reader + contact mutations |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @contact_read_tools [
    "salesforce.contacts.contact.get",
    "salesforce.contacts.contact.list"
  ]

  @generic_read_tools [
    "salesforce.crm.query",
    "salesforce.crm.record.get",
    "salesforce.crm.object.describe",
    "salesforce.crm.record.list_recent",
    "salesforce.crm.query_more"
  ]

  @reader_tools @contact_read_tools ++ @generic_read_tools

  @contact_write_tools [
    "salesforce.contacts.contact.create",
    "salesforce.contacts.contact.update"
  ]

  @lead_write_tools [
    "salesforce.crm.lead.create",
    "salesforce.crm.lead.update"
  ]

  @task_write_tools [
    "salesforce.crm.task.create",
    "salesforce.crm.task.update"
  ]

  @generic_write_tools [
    "salesforce.crm.record.create",
    "salesforce.crm.record.update"
  ]

  @write_tools @contact_write_tools ++
                 @lead_write_tools ++ @task_write_tools ++ @generic_write_tools

  @editor_tools @reader_tools ++ @write_tools

  @doc "Returns all built-in Salesforce catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Salesforce CRM pack for contact queries and generic reads."
  def reader do
    Pack.new!(%{
      id: :salesforce_reader,
      label: "Salesforce reader",
      description:
        "Read Salesforce CRM contacts and generic SObject records without mutation tools.",
      filters: %{provider: :salesforce},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_salesforce, risk: :read}
    })
  end

  @doc "Salesforce editor pack for CRM read and contact mutations."
  def editor do
    Pack.new!(%{
      id: :salesforce_editor,
      label: "Salesforce editor",
      description:
        "Read Salesforce CRM contacts and generic SObject records, and create new contacts.",
      filters: %{provider: :salesforce},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_salesforce, risk: :write}
    })
  end
end
