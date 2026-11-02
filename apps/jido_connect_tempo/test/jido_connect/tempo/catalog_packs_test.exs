defmodule Jido.Connect.Tempo.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.AI.CatalogToolSource
  alias Jido.Connect.Catalog
  alias Jido.Connect.Tempo

  test "catalog_packs returns the reader and the period lookup pack" do
    assert [%{id: :tempo_reader} = reader, %{id: :tempo_period_lookup} = lookup] =
             Tempo.catalog_packs()

    assert Tempo.catalog_packs() == Tempo.CatalogPacks.all()

    for pack <- [reader, lookup] do
      assert pack.filters == %{provider: :tempo}
      assert pack.metadata == %{package: :jido_connect_tempo, risk: :read}
    end
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

  test "the period lookup pack selects the period bookability read and no mutation" do
    results =
      Catalog.search_tools("tempo",
        modules: [Tempo],
        packs: Tempo.catalog_packs(),
        pack: :tempo_period_lookup
      )

    assert Enum.map(results, & &1.tool.id) == ["tempo.period.bookability.get"]
    assert Enum.map(results, & &1.tool.risk) == [:read]

    assert {:ok, [%{id: "tempo.period.bookability.get", risk: :read}]} =
             Catalog.reviewed_items(Tempo, Tempo.CatalogPacks.period_lookup())

    assert {:ok, %{mutation?: false, risk: :read}} =
             Jido.Connect.action(Tempo.integration(), "tempo.period.bookability.get")
  end

  test "both packs can become AI tool sources" do
    assert {:ok, _source} = CatalogToolSource.new(Tempo, Tempo.CatalogPacks.reader())
    assert {:ok, _source} = CatalogToolSource.new(Tempo, Tempo.CatalogPacks.period_lookup())
  end
end
