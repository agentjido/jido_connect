defmodule Jido.Connect.Airtable.Handlers.Actions.GetBaseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Base
  alias Jido.Connect.Airtable.Handlers.Actions.GetBase

  describe "run/2" do
    test "returns base on success" do
      base = Base.new!(%{base_id: "appTest1", name: "Test Base"})
      MockClient.stub(get_base: {:ok, base})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{base: result}} =
               GetBase.run(%{base_id: "appTest1"}, %{credentials: credentials})

      assert result.base_id == "appTest1"
      assert result.name == "Test Base"
    end

    test "returns base with tables in metadata" do
      base =
        Base.new!(%{
          base_id: "appTest1",
          name: "Test Base",
          metadata: %{
            tables: [
              %{"id" => "tbl1", "name" => "Tasks"},
              %{"id" => "tbl2", "name" => "People"}
            ]
          }
        })

      MockClient.stub(get_base: {:ok, base})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{base: result}} =
               GetBase.run(%{base_id: "appTest1"}, %{credentials: credentials})

      assert result.metadata.tables != nil
      assert length(result.metadata.tables) == 2
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Not found"}}

      MockClient.stub(get_base: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetBase.run(%{base_id: "appInvalid"}, %{credentials: credentials})
    end
  end
end
