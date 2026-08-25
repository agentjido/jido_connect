defmodule Jido.Connect.ReviewedCatalogTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Fingerprint
  alias Jido.Connect.CatalogFixtures

  defmodule ChangedOutputIntegration do
    alias Jido.Connect
    alias Jido.Connect.CatalogFixtures

    def integration do
      spec = CatalogFixtures.Integration.integration()
      action = hd(spec.actions)

      output =
        action.output ++
          [
            Connect.Field.new!(%{
              name: :updated_at,
              type: :string,
              required?: true
            })
          ]

      %{
        spec
        | actions: [
            %{action | output: output, output_schema: Connect.zoi_schema_from_fields(output)}
          ]
      }
    end
  end

  defmodule GenericMcpBridgeIntegration do
    alias Jido.Connect.CatalogFixtures

    def integration do
      spec = CatalogFixtures.Integration.integration()
      action = hd(spec.actions)

      %{
        spec
        | id: :mcp_bridge_fixture,
          package: :jido_connect_mcp,
          metadata: %{package: :jido_connect_mcp, version: "test"},
          actions: [%{action | id: "mcp.tools.list", name: :tools_list, label: "List MCP tools"}]
      }
    end
  end

  defmodule ChangedPublicMetadataIntegration do
    alias Jido.Connect.CatalogFixtures

    def integration do
      spec = CatalogFixtures.Integration.integration()
      action = hd(spec.actions)

      %{
        spec
        | actions: [
            %{action | metadata: %{public_revision: "2"}}
          ]
      }
    end
  end

  test "projects only exact reviewed pack actions without discovery" do
    pack =
      Catalog.Pack.new!(%{
        id: :catalog_reader,
        label: "Catalog reader",
        filters: %{type: :action},
        allowed_tools: ["catalog.item.get"],
        metadata: %{access_token: "not-public"}
      })

    Application.put_env(:jido_connect, :catalog_modules, [CatalogFixtures.OtherIntegration])

    on_exit(fn -> Application.delete_env(:jido_connect, :catalog_modules) end)

    assert {:ok,
            [
              %Catalog.ToolDescriptor{
                tool: %{id: "catalog.item.get", type: :action},
                pack: %{id: "catalog_reader"},
                reviewed_fingerprint: fingerprint,
                metadata: %{
                  provider: :catalog,
                  package: :jido_connect_catalog,
                  pack: %{id: "catalog_reader"},
                  risk: :read,
                  confirmation: :none,
                  scopes: ["read"],
                  policies: [:item_access]
                }
              } = descriptor
            ]} = Catalog.reviewed_descriptors(CatalogFixtures.Integration, pack)

    assert String.starts_with?(
             fingerprint,
             "jido_connect.catalog.fingerprint.v1:reviewed_descriptor:"
           )

    refute inspect(Catalog.to_map(descriptor)) =~ "not-public"
  end

  test "projects reviewed items as the canonical fingerprinted form" do
    pack =
      Catalog.Pack.new!(%{
        id: :catalog_reader,
        allowed_tools: ["catalog:action:catalog.item.get"]
      })

    assert {:ok,
            [
              %Catalog.Item{
                ref: "catalog:action:catalog.item.get",
                pack: %{id: "catalog_reader"},
                reviewed_fingerprint: fingerprint
              }
            ]} = Catalog.reviewed_items(CatalogFixtures.Integration, pack)

    assert String.starts_with?(
             fingerprint,
             "jido_connect.catalog.fingerprint.v1:reviewed_descriptor:"
           )
  end

  test "rejects a reviewed pack action that is missing from the exact modules" do
    pack = Catalog.Pack.new!(%{id: :missing, allowed_tools: ["missing.action"]})

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :pack_action_missing}} =
             Catalog.reviewed_descriptors([CatalogFixtures.Integration], pack)
  end

  test "rejects triggers in executable reviewed packs" do
    pack = Catalog.Pack.new!(%{id: :triggers, allowed_tools: ["catalog.item.created"]})

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :trigger_not_executable}} =
             Catalog.reviewed_descriptors([CatalogFixtures.Integration], pack)
  end

  test "rejects generic MCP bridge actions from the reviewed projection" do
    pack = Catalog.Pack.new!(%{id: :bridge, allowed_tools: ["mcp.tools.list"]})

    assert {:error,
            %Jido.Connect.Error.ValidationError{reason: :generic_mcp_action_not_reviewable}} =
             Catalog.reviewed_descriptors([GenericMcpBridgeIntegration], pack)
  end

  test "changes reviewed fingerprints when an output schema changes" do
    pack =
      Catalog.Pack.new!(%{
        id: :catalog_reader,
        filters: %{type: :action},
        allowed_tools: ["catalog.item.get"]
      })

    assert {:ok, [%{reviewed_fingerprint: original}]} =
             Catalog.reviewed_descriptors([CatalogFixtures.Integration], pack)

    assert {:ok, [%{reviewed_fingerprint: changed}]} =
             Catalog.reviewed_descriptors([ChangedOutputIntegration], pack)

    refute original == changed
  end

  test "preserves public descriptor metadata and fingerprints its changes" do
    pack = Catalog.Pack.new!(%{id: :catalog_reader, allowed_tools: ["catalog.item.get"]})

    assert {:ok, [%{metadata: original_metadata, reviewed_fingerprint: original}]} =
             Catalog.reviewed_descriptors(CatalogFixtures.Integration, pack)

    assert original_metadata.version == "1.2.3"
    refute Map.has_key?(original_metadata, :access_token)

    assert {:ok, [%{metadata: %{public_revision: "2"}, reviewed_fingerprint: changed}]} =
             Catalog.reviewed_descriptors(ChangedPublicMetadataIntegration, pack)

    refute original == changed
  end

  test "uses stable canonical fingerprints across map order and processes" do
    left = %{"schema" => %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}}}
    right = %{"schema" => %{"properties" => %{"id" => %{"type" => "string"}}, "type" => "object"}}

    assert Fingerprint.remote_input(left) == Fingerprint.remote_input(right)
    refute Fingerprint.reviewed_descriptor(left) == Fingerprint.remote_input(left)

    assert Fingerprint.remote_input(%{schema: %{"type" => "object"}}) ==
             Fingerprint.remote_input(%{"schema" => %{"type" => "object"}})

    assert_raise ArgumentError, ~r/duplicate normalized map keys/, fn ->
      Fingerprint.remote_input(%{"schema" => "string", schema: "atom"})
    end

    assert_raise ArgumentError, ~r/duplicate normalized map keys/, fn ->
      Fingerprint.remote_input(%{"schema" => %{"type" => "string", type: "atom"}})
    end

    pack = Catalog.Pack.new!(%{id: :catalog_reader, allowed_tools: ["catalog.item.get"]})

    assert {:ok, [%{reviewed_fingerprint: fingerprint}]} =
             Catalog.reviewed_descriptors([CatalogFixtures.Integration], pack)

    task =
      Task.async(fn ->
        {:ok, [%{reviewed_fingerprint: repeated}]} =
          Catalog.reviewed_descriptors([CatalogFixtures.Integration], pack)

        repeated
      end)

    assert Task.await(task) == fingerprint
  end
end
