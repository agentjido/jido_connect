defmodule Jido.Connect.InboundWebhook.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Catalog
  alias Jido.Connect.InboundWebhook

  describe "catalog_packs/0" do
    test "returns verifier and receiver packs" do
      packs = InboundWebhook.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert pack_ids == [:webhook_verifier, :webhook_receiver]
    end

    test "all packs reference webhook provider and correct package" do
      for pack <- InboundWebhook.catalog_packs() do
        assert pack.filters == %{provider: :webhook}
        assert pack.metadata.package == :jido_connect_webhook
      end
    end
  end

  describe "verifier pack" do
    test "exposes no trigger tools" do
      results =
        Catalog.search_tools("webhook",
          modules: [InboundWebhook],
          packs: InboundWebhook.catalog_packs(),
          pack: :webhook_verifier
        )

      ids = Enum.map(results, & &1.tool.id)
      refute "webhook.inbound.delivery" in ids
    end

    test "pack metadata includes hmac_verification capability" do
      pack = InboundWebhook.verifier_pack()

      assert pack.id == :webhook_verifier
      assert :hmac_verification in pack.metadata.capabilities
      refute :inbound_delivery in pack.metadata.capabilities
      assert pack.metadata.risk == :read
    end
  end

  describe "receiver pack" do
    test "exposes inbound delivery trigger" do
      results =
        Catalog.search_tools("webhook",
          modules: [InboundWebhook],
          packs: InboundWebhook.catalog_packs(),
          pack: :webhook_receiver
        )

      ids = Enum.map(results, & &1.tool.id)
      assert "webhook.inbound.delivery" in ids
    end

    test "describe_tool accepts inbound delivery trigger in receiver pack" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("webhook.inbound.delivery",
                 modules: [InboundWebhook],
                 packs: InboundWebhook.catalog_packs(),
                 pack: :webhook_receiver
               )

      assert descriptor.tool.id == "webhook.inbound.delivery"
    end

    test "describe_tool rejects inbound delivery trigger in verifier pack" do
      assert {:error, %{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("webhook.inbound.delivery",
                 modules: [InboundWebhook],
                 packs: InboundWebhook.catalog_packs(),
                 pack: :webhook_verifier
               )
    end

    test "pack metadata includes both capabilities" do
      pack = InboundWebhook.receiver_pack()

      assert pack.id == :webhook_receiver
      assert :hmac_verification in pack.metadata.capabilities
      assert :inbound_delivery in pack.metadata.capabilities
      assert pack.metadata.risk == :read
    end
  end

  describe "pack delegates" do
    test "verifier_pack/0 returns verifier" do
      pack = InboundWebhook.verifier_pack()
      assert pack.id == :webhook_verifier
    end

    test "receiver_pack/0 returns receiver" do
      pack = InboundWebhook.receiver_pack()
      assert pack.id == :webhook_receiver
    end
  end
end
