defmodule Jido.Connect.Tempo.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.AI.CatalogToolSource
  alias Jido.Connect.Catalog
  alias Jido.Connect.Tempo

  test "catalog_packs returns the reader pack only" do
    assert [%{id: :tempo_reader} = pack] = Tempo.catalog_packs()
    assert Tempo.catalog_packs() == Tempo.CatalogPacks.all()
    assert pack.filters == %{provider: :tempo}
    assert pack.metadata == %{package: :jido_connect_tempo, risk: :read}
  end

  test "the reader pack selects the own worklog read and no mutation" do
    results =
      Catalog.search_tools("tempo",
        modules: [Tempo],
        packs: Tempo.catalog_packs(),
        pack: :tempo_reader
      )

    assert Enum.map(results, & &1.tool.id) == ["tempo.worklogs.list_own"]
    assert Enum.map(results, & &1.tool.risk) == [:read]

    assert {:ok, [%{id: "tempo.worklogs.list_own", risk: :read}]} =
             Catalog.reviewed_items(Tempo, Tempo.CatalogPacks.reader())

    assert {:ok, %{mutation?: false, risk: :read}} =
             Jido.Connect.action(Tempo.integration(), "tempo.worklogs.list_own")
  end

  test "the reader pack can become an AI tool source" do
    assert {:ok, _source} = CatalogToolSource.new(Tempo, Tempo.CatalogPacks.reader())
  end
end
