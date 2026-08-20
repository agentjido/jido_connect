defmodule Jido.Connect.Bitbucket.CatalogPacks do
  @moduledoc "Curated read-only Bitbucket catalog packs."

  alias Jido.Connect.Catalog.Pack

  @reader_tools ["bitbucket.pull_request.list"]

  @doc "Returns all built-in Bitbucket catalog packs."
  def all, do: [reader()]

  @doc "Read-only pack for the reviewed Bitbucket pull-request action."
  def reader do
    Pack.new!(%{
      id: :bitbucket_reader,
      label: "Bitbucket reader",
      description: "List Bitbucket pull requests without mutation tools.",
      filters: %{provider: :bitbucket},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_bitbucket, risk: :read}
    })
  end
end
