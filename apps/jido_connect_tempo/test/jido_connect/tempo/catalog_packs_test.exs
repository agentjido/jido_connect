defmodule Jido.Connect.Tempo.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.AI.CatalogToolSource
  alias Jido.Connect.Catalog
  alias Jido.Connect.Tempo

  test "catalog_packs returns the two read packs and the writer pack" do
    assert [
             %{id: :tempo_reader} = reader,
             %{id: :tempo_period_lookup} = lookup,
             %{id: :tempo_writer} = writer
           ] = Tempo.catalog_packs()

    assert Tempo.catalog_packs() == Tempo.CatalogPacks.all()

    for pack <- [reader, lookup] do
      assert pack.filters == %{provider: :tempo}
      assert pack.metadata == %{package: :jido_connect_tempo, risk: :read}
    end

    assert reader.allowed_tools == ["tempo.worklogs.list_own"]
    assert lookup.allowed_tools == ["tempo.period.bookability.get"]
    assert writer.filters == %{provider: :tempo}
    assert writer.metadata == %{package: :jido_connect_tempo, risk: :write}
  end

  test "the writer pack selects the worklog create and nothing else" do
    results =
      Catalog.search_tools("tempo",
        modules: [Tempo],
        packs: Tempo.catalog_packs(),
        pack: :tempo_writer
      )

    assert Enum.map(results, & &1.tool.id) == ["tempo.worklog.create"]
    assert Enum.map(results, & &1.tool.risk) == [:write]

    assert {:ok, [%{id: "tempo.worklog.create", risk: :write}]} =
             Catalog.reviewed_items(Tempo, Tempo.CatalogPacks.writer())
  end

  test "neither read pack offers the worklog create" do
    for pack <- [:tempo_reader, :tempo_period_lookup] do
      ids =
        "worklog create"
        |> Catalog.search_tools(modules: [Tempo], packs: Tempo.catalog_packs(), pack: pack)
        |> Enum.map(& &1.tool.id)

      refute "tempo.worklog.create" in ids
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

  test "the read packs can become AI tool sources, the writer pack cannot" do
    assert {:ok, _source} = CatalogToolSource.new(Tempo, Tempo.CatalogPacks.reader())
    assert {:ok, _source} = CatalogToolSource.new(Tempo, Tempo.CatalogPacks.period_lookup())

    # The core offers no mutation as a direct AI tool; it goes through
    # prepare/4 and commit/4.
    assert {:error,
            %Jido.Connect.Error.ValidationError{reason: :catalog_mutation_tool_not_enabled}} =
             CatalogToolSource.new(Tempo, Tempo.CatalogPacks.writer())
  end
end
