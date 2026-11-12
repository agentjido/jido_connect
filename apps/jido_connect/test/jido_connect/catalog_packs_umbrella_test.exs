defmodule Jido.Connect.CatalogPacksUmbrellaTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.AI.CatalogToolSource
  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Pack
  alias Jido.Connect.Taxonomy

  @non_provider_integrations [Jido.Connect.MCP]

  test "every registered Action provider exposes AI-compatible CatalogPacks" do
    integrations = action_integrations()

    assert length(integrations) == 37

    Enum.each(integrations, fn integration ->
      pack_module = Module.concat(integration, CatalogPacks)

      assert Code.ensure_loaded?(pack_module),
             "#{inspect(integration)} must define #{inspect(pack_module)}"

      assert function_exported?(pack_module, :all, 0),
             "#{inspect(pack_module)} must export all/0"

      assert function_exported?(integration, :catalog_packs, 0),
             "#{inspect(integration)} must export catalog_packs/0"

      packs = apply(pack_module, :all, [])

      assert packs == apply(integration, :catalog_packs, [])

      assert is_list(packs) and packs != [],
             "#{inspect(pack_module)}.all/0 must return a non-empty pack list"

      assert Enum.all?(packs, &match?(%Pack{}, &1))
      assert Enum.map(packs, & &1.id) == Enum.uniq(Enum.map(packs, & &1.id))

      Enum.each(packs, &assert_pack_compatibility(integration, &1))
    end)
  end

  defp action_integrations do
    Catalog.registered_modules()
    |> Enum.reject(&(&1 in @non_provider_integrations))
    |> Enum.filter(fn integration ->
      case Jido.Connect.spec(integration) do
        {:ok, %{actions: [_ | _]}} -> true
        _other -> false
      end
    end)
    |> Enum.sort()
  end

  defp assert_pack_compatibility(integration, pack) do
    assert Taxonomy.known_pack_risk?(pack.metadata.risk),
           "#{inspect(integration)} pack #{inspect(pack.id)} needs a standard risk label"

    assert {:ok, items} = Catalog.reviewed_items(integration, pack)
    assert items != [], "#{inspect(integration)} pack #{inspect(pack.id)} selects no Actions"

    if Enum.all?(items, &(&1.risk in [:read, :metadata])) do
      assert pack.metadata.risk in [:read, :metadata]
      assert {:ok, source} = CatalogToolSource.new(integration, pack)
      assert {:ok, [_ | _]} = Jido.AI.ToolSource.load(%{jido_ai_tool_sources: [source]})
    else
      assert pack.metadata.risk in [:write, :privileged, :destructive, :mixed]

      if Enum.any?(items, &(&1.risk == :destructive)) do
        assert pack.metadata.risk in [:destructive, :mixed],
               "#{inspect(integration)} pack #{inspect(pack.id)} contains a destructive Action"
      end

      assert {:error,
              %Jido.Connect.Error.ValidationError{
                reason: :catalog_mutation_tool_not_enabled
              }} = CatalogToolSource.new(integration, pack)
    end
  end
end
